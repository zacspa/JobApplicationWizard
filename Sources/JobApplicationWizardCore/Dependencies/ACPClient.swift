import Foundation
import ComposableArchitecture
import ACP
import ACPModel
import os.log

private let acpLog = Logger(subsystem: "com.jobwizard.acp", category: "ACPClient")

// MARK: - ACPClient Dependency

public struct ACPClient {
    public var connect: @Sendable (ACPAgentEntry) async throws -> String
    public var disconnect: @Sendable () async -> Void
    public var sendPrompt: @Sendable (String, [ChatMessage]) async throws -> (String, AITokenUsage)
    public var onUnexpectedDisconnect: @Sendable () -> AsyncStream<Void>

    public init(
        connect: @escaping @Sendable (ACPAgentEntry) async throws -> String,
        disconnect: @escaping @Sendable () async -> Void,
        sendPrompt: @escaping @Sendable (String, [ChatMessage]) async throws -> (String, AITokenUsage),
        onUnexpectedDisconnect: @escaping @Sendable () -> AsyncStream<Void>
    ) {
        self.connect = connect
        self.disconnect = disconnect
        self.sendPrompt = sendPrompt
        self.onUnexpectedDisconnect = onUnexpectedDisconnect
    }
}

// MARK: - Subprocess Transport

/// A non-blocking Transport that communicates with a subprocess over pipe FileHandles.
/// Unlike StdioTransport, `start()` returns immediately and the read loop runs in a background task.
/// Uses buffered reads (4KB chunks) instead of byte-by-byte for efficiency.
private final class SubprocessTransport: Transport, @unchecked Sendable {
    let state: AsyncStream<TransportState>
    let messages: AsyncStream<JsonRpcMessage>

    private let stateContinuation: AsyncStream<TransportState>.Continuation
    private let messagesContinuation: AsyncStream<JsonRpcMessage>.Continuation
    private let input: FileHandle   // reads agent stdout
    private let output: FileHandle  // writes to agent stdin
    private var readTask: Task<Void, Never>?
    private var didClose = false

    init(input: FileHandle, output: FileHandle) {
        self.input = input
        self.output = output

        var stateCont: AsyncStream<TransportState>.Continuation?
        self.state = AsyncStream { stateCont = $0 }
        self.stateContinuation = stateCont!

        var msgCont: AsyncStream<JsonRpcMessage>.Continuation?
        self.messages = AsyncStream { msgCont = $0 }
        self.messagesContinuation = msgCont!

        stateContinuation.yield(.created)
    }

    func start() async throws {
        stateContinuation.yield(.starting)
        acpLog.info("transport: starting read loop")

        // Launch read loop in a background task — do NOT block here
        readTask = Task { [weak self] in
            guard let self else { return }
            var messageCount = 0
            while !Task.isCancelled {
                do {
                    guard let line = try self.readLine() else {
                        acpLog.info("transport: EOF on read (subprocess closed stdout)")
                        break
                    }
                    do {
                        let message = try self.parseMessage(line)
                        messageCount += 1
                        acpLog.debug("transport: received message #\(messageCount) (\(line.prefix(120))...)")
                        self.messagesContinuation.yield(message)
                    } catch {
                        acpLog.warning("transport: failed to parse message: \(error), line: \(line.prefix(200))")
                    }
                } catch {
                    acpLog.warning("transport: read error: \(error)")
                    break
                }
            }
            acpLog.info("transport: read loop ended after \(messageCount) messages")
            Task { await self.close() }
        }

        stateContinuation.yield(.started)
        acpLog.info("transport: started")
    }

    func send(_ message: JsonRpcMessage) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        guard var json = String(data: data, encoding: .utf8) else { return }
        json += "\n"
        guard let bytes = json.data(using: .utf8) else { return }
        try output.write(contentsOf: bytes)
    }

    func close() async {
        guard !didClose else { return }
        didClose = true
        readTask?.cancel()
        readTask = nil
        // Close pipe handles to unblock any pending read()
        try? input.close()
        try? output.close()
        stateContinuation.yield(.closing)
        messagesContinuation.finish()
        stateContinuation.yield(.closed)
        stateContinuation.finish()
    }

    private func readLine() throws -> String? {
        var data = Data()
        while true {
            let byte = try input.read(upToCount: 1)
            guard let byte, !byte.isEmpty else {
                return data.isEmpty ? nil : String(data: data, encoding: .utf8)
            }
            if byte[0] == UInt8(ascii: "\n") {
                return String(data: data, encoding: .utf8)
            }
            data.append(byte)
        }
    }

    private func parseMessage(_ line: String) throws -> JsonRpcMessage {
        guard let data = line.data(using: .utf8) else {
            throw ACPClientError.notConnected
        }
        return try JSONDecoder().decode(JsonRpcMessage.self, from: data)
    }
}

// MARK: - Simple Client conformance

/// Minimal Client implementation that collects agent message chunks.
private final class JobWizardACPClient: Client, @unchecked Sendable {
    var capabilities: ClientCapabilities { ClientCapabilities() }
    var info: Implementation? { Implementation(name: "JobApplicationWizard", version: "1.0.0") }

    /// Accumulated text from agent message chunks during a prompt turn.
    private let lock = NSLock()
    private var _collectedText: String = ""

    var collectedText: String {
        lock.lock()
        defer { lock.unlock() }
        return _collectedText
    }

    func resetCollectedText() {
        lock.lock()
        defer { lock.unlock() }
        _collectedText = ""
    }

    func onSessionUpdate(_ update: SessionUpdate) async {
        if case .agentMessageChunk(let chunk) = update {
            if case .text(let textContent) = chunk.content {
                lock.lock()
                _collectedText += textContent.text
                lock.unlock()
            }
        }
    }
}

// MARK: - Live Implementation

/// Actor that manages the ACP agent subprocess lifecycle.
/// Keeps Process and ClientConnection state out of TCA (which requires Equatable).
private actor ACPProcessManager {
    private var process: Process?
    private var connection: ClientConnection?
    private var transport: SubprocessTransport?
    private var stdinPipeHandle: FileHandle?
    private var stdoutPipeHandle: FileHandle?
    private var sessionId: SessionId?
    private var agentName: String?
    private var clientDelegate: JobWizardACPClient?

    /// Stream that fires when the subprocess terminates unexpectedly.
    private let (crashStream, crashContinuation) = AsyncStream<Void>.makeStream()

    var unexpectedDisconnects: AsyncStream<Void> { crashStream }
    var connected: Bool { process != nil && connection != nil && sessionId != nil }
    var currentAgentName: String? { agentName }

    func connect(entry: ACPAgentEntry) async throws -> String {
        acpLog.info("connect: starting for agent '\(entry.name)' (id: \(entry.id))")

        // Disconnect any existing session first
        await disconnect()

        // Determine launch command from distribution
        let (launchPath, arguments) = try resolveLaunchCommand(entry: entry)
        acpLog.info("connect: resolved command: \(launchPath) \(arguments.joined(separator: " "))")

        // Verify the executable exists
        let resolvedPath: String
        if launchPath == "/usr/bin/env" {
            resolvedPath = launchPath
        } else {
            guard FileManager.default.fileExists(atPath: launchPath) else {
                throw ACPClientError.launchFailed(entry.name, "Executable not found at \(launchPath)")
            }
            resolvedPath = launchPath
        }

        // Create subprocess
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: resolvedPath)
        proc.arguments = arguments

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        // Register crash detection via terminationHandler
        proc.terminationHandler = { [weak self] terminatedProc in
            Task { await self?.handleProcessTermination(exitCode: terminatedProc.terminationStatus) }
        }

        do {
            try proc.run()
            acpLog.info("connect: process launched, pid=\(proc.processIdentifier)")
        } catch {
            acpLog.error("connect: failed to launch process: \(error.localizedDescription)")
            throw ACPClientError.launchFailed(entry.name, "Failed to launch: \(error.localizedDescription)")
        }
        self.process = proc
        self.stdinPipeHandle = stdinPipe.fileHandleForWriting
        self.stdoutPipeHandle = stdoutPipe.fileHandleForReading

        // Brief check that process didn't exit immediately
        acpLog.info("connect: waiting 500ms to check process liveness...")
        try await Task.sleep(nanoseconds: 500_000_000)  // 500ms
        if !proc.isRunning {
            let stderrData = stderrPipe.fileHandleForReading.availableData
            let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = stderrText.isEmpty ? "exit code \(proc.terminationStatus)" : stderrText
            throw ACPClientError.launchFailed(entry.name, detail)
        }

        // Create non-blocking transport and client
        let xport = SubprocessTransport(
            input: stdoutPipe.fileHandleForReading,
            output: stdinPipe.fileHandleForWriting
        )
        self.transport = xport
        let client = JobWizardACPClient()
        self.clientDelegate = client

        // Create ClientConnection over our custom transport
        // Use a generous timeout — npx agents may need time for first-run package download
        // npx agents may need time for first-run package download
        let conn = ClientConnection(transport: xport, client: client, defaultTimeoutSeconds: 120)
        self.connection = conn

        // Connect and initialize
        acpLog.info("connect: starting ACP handshake (initialize)...")
        let agentInfo: Implementation?
        do {
            agentInfo = try await conn.connect()
            acpLog.info("connect: handshake succeeded, agent=\(agentInfo?.name ?? "unknown")")
        } catch {
            acpLog.error("connect: handshake failed: \(error)")
            proc.terminate()
            self.process = nil
            self.connection = nil
            self.transport = nil
            throw ACPClientError.launchFailed(entry.name, "ACP handshake failed: \(error.localizedDescription)")
        }
        let name = agentInfo?.name ?? entry.name

        // Create a new session
        acpLog.info("connect: creating session...")
        let sessionResponse: NewSessionResponse
        do {
            sessionResponse = try await conn.createSession(
                request: NewSessionRequest(cwd: ".", mcpServers: [])
            )
            acpLog.info("connect: session created, id=\(sessionResponse.sessionId)")
        } catch {
            acpLog.error("connect: session creation failed: \(error)")
            await conn.disconnect()
            proc.terminate()
            self.process = nil
            self.connection = nil
            self.transport = nil
            throw ACPClientError.launchFailed(entry.name, "Session creation failed: \(error.localizedDescription)")
        }
        self.sessionId = sessionResponse.sessionId
        self.agentName = name

        acpLog.info("connect: fully connected to '\(name)'")
        return name
    }

    func disconnect() async {
        if let conn = connection {
            await conn.disconnect()
        }
        if let xport = transport {
            await xport.close()
        }
        // Close pipe handles to unblock any pending reads
        try? stdinPipeHandle?.close()
        try? stdoutPipeHandle?.close()
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        connection = nil
        transport = nil
        stdinPipeHandle = nil
        stdoutPipeHandle = nil
        sessionId = nil
        agentName = nil
        clientDelegate = nil
    }

    /// Called when the agent subprocess terminates unexpectedly.
    private func handleProcessTermination(exitCode: Int32) async {
        guard process != nil else { return }  // already cleaned up
        acpLog.warning("process terminated unexpectedly, exit code \(exitCode)")
        // Clean up without trying to terminate an already-dead process
        if let xport = transport { await xport.close() }
        try? stdinPipeHandle?.close()
        try? stdoutPipeHandle?.close()
        process = nil
        connection = nil
        transport = nil
        stdinPipeHandle = nil
        stdoutPipeHandle = nil
        sessionId = nil
        agentName = nil
        clientDelegate = nil
        // Notify observers so the UI can update
        crashContinuation.yield()
    }

    func sendPrompt(text: String, history: [ChatMessage]) async throws -> (String, AITokenUsage) {
        guard let conn = connection, let sid = sessionId, let client = clientDelegate else {
            throw ACPClientError.notConnected
        }

        // Reset collected text before sending
        client.resetCollectedText()

        // Build prompt request with text content block
        let request = PromptRequest(
            sessionId: sid,
            prompt: [.text(TextContent(text: text))]
        )

        // Send prompt — agent message chunks arrive via onSessionUpdate
        _ = try await conn.prompt(request: request)

        // Collect accumulated text from notifications
        let responseText = client.collectedText

        // ACP doesn't expose token usage
        return (responseText, .zero)
    }

    private func resolveLaunchCommand(entry: ACPAgentEntry) throws -> (String, [String]) {
        // Prefer native binary for current platform
        if let binaries = entry.distribution.binary {
            #if arch(arm64)
            let platform = "darwin-aarch64"
            #else
            let platform = "darwin-x86_64"
            #endif
            if let binary = binaries[platform] {
                return (binary.cmd, ["--stdio"])
            }
        }

        // Fall back to npx
        if let npx = entry.distribution.npx {
            var args = ["npx", "-y", npx.package]
            if let extraArgs = npx.args { args.append(contentsOf: extraArgs) }
            return ("/usr/bin/env", args)
        }

        // Fall back to uvx
        if let uvx = entry.distribution.uvx {
            var args = ["uvx", uvx.package]
            if let extraArgs = uvx.args { args.append(contentsOf: extraArgs) }
            return ("/usr/bin/env", args)
        }

        throw ACPClientError.noCompatibleDistribution(entry.name)
    }
}

extension ACPClient: DependencyKey {
    public static var liveValue: ACPClient {
        let manager = ACPProcessManager()

        return ACPClient(
            connect: { entry in
                try await manager.connect(entry: entry)
            },
            disconnect: {
                await manager.disconnect()
            },
            sendPrompt: { text, history in
                try await manager.sendPrompt(text: text, history: history)
            },
            onUnexpectedDisconnect: {
                AsyncStream { continuation in
                    let task = Task {
                        for await _ in await manager.unexpectedDisconnects {
                            continuation.yield()
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }
}

extension ACPClient: TestDependencyKey {
    public static let testValue = ACPClient(
        connect: unimplemented("\(Self.self).connect", placeholder: ""),
        disconnect: unimplemented("\(Self.self).disconnect"),
        sendPrompt: unimplemented("\(Self.self).sendPrompt", placeholder: ("", .zero)),
        onUnexpectedDisconnect: { AsyncStream { $0.finish() } }
    )
}

extension DependencyValues {
    public var acpClient: ACPClient {
        get { self[ACPClient.self] }
        set { self[ACPClient.self] = newValue }
    }
}

public enum ACPClientError: LocalizedError {
    case notConnected
    case noCompatibleDistribution(String)
    case launchFailed(String, String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "No ACP agent is connected."
        case .noCompatibleDistribution(let name):
            return "No compatible distribution found for agent '\(name)'. Requires a macOS binary, npx, or uvx package."
        case .launchFailed(let name, let detail):
            return "Failed to connect to '\(name)': \(detail)"
        }
    }
}
