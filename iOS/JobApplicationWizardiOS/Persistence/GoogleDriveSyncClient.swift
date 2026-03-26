import Foundation
import CryptoKit
import JobApplicationShared
import AuthenticationServices

// MARK: - Google Drive Sync Implementation

/// Implements SyncClient using Google Drive REST API v3 with the appdata scope.
/// Uses OAuth 2.0 via ASWebAuthenticationSession (no Google SDK dependency).
enum GoogleDriveSync {

    // MARK: - Configuration

    // TODO: Replace with your OAuth client ID from Google Cloud Console
    static let clientID = "REDACTED_OAUTH_CLIENT_ID.apps.googleusercontent.com"
    static let redirectURI = "com.googleusercontent.apps.REDACTED_OAUTH_CLIENT_ID:/oauth2callback"
    static let scope = "https://www.googleapis.com/auth/drive.appdata"
    static let tokenURL = "https://oauth2.googleapis.com/token"
    static let driveFilesURL = "https://www.googleapis.com/drive/v3/files"
    static let driveUploadURL = "https://www.googleapis.com/upload/drive/v3/files"

    // MARK: - Token Storage

    private static let tokenKey = "google_drive_refresh_token"
    private static let tokenManager = TokenManager()

    static var isAuthenticated: Bool {
        getRefreshToken() != nil
    }

    // MARK: - HTTP Helpers

    private static func checkedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.driveAPIError("HTTP \(httpResponse.statusCode): \(body)")
        }
        return data
    }

    private static let formURLAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return allowed
    }()

    private static func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: formURLAllowed) ?? string
    }

    // MARK: - OAuth Flow

    /// Authenticate via OAuth 2.0 using ASWebAuthenticationSession.
    @MainActor
    static func authenticate() async throws {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        let authURL = components.url!
        let callbackScheme = "com.googleusercontent.apps.REDACTED_OAUTH_CLIENT_ID"

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { url, error in
                WebAuthContextProvider.shared.currentSession = nil
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: SyncError.notAuthenticated)
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = WebAuthContextProvider.shared
            WebAuthContextProvider.shared.currentSession = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw SyncError.notAuthenticated
        }

        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
    }

    // MARK: - Token Management

    private static func exchangeCodeForTokens(code: String, codeVerifier: String) async throws {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code=\(urlEncode(code))",
            "client_id=\(urlEncode(clientID))",
            "redirect_uri=\(urlEncode(redirectURI))",
            "grant_type=authorization_code",
            "code_verifier=\(urlEncode(codeVerifier))",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let data = try await checkedData(for: request)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        await tokenManager.setToken(tokenResponse)

        if let refreshToken = tokenResponse.refresh_token {
            saveRefreshToken(refreshToken)
        }
    }

    private static func refreshAccessToken() async throws {
        guard let refreshToken = getRefreshToken() else {
            throw SyncError.notAuthenticated
        }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "refresh_token=\(urlEncode(refreshToken))",
            "client_id=\(urlEncode(clientID))",
            "grant_type=refresh_token",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let data = try await checkedData(for: request)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        await tokenManager.setToken(tokenResponse)
    }

    static func getValidAccessToken() async throws -> String {
        try await tokenManager.getValidToken(refreshing: refreshAccessToken)
    }

    // MARK: - Keychain Helpers

    private static func saveRefreshToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.zsparks.JobApplicationWizard.gdrive",
            kSecAttrAccount as String: tokenKey,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func getRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.zsparks.JobApplicationWizard.gdrive",
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteRefreshToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.zsparks.JobApplicationWizard.gdrive",
            kSecAttrAccount as String: tokenKey,
        ]
        SecItemDelete(query as CFDictionary)
        Task { await tokenManager.clear() }
    }

    // MARK: - Drive API: File Operations

    /// List files in the appDataFolder matching a query.
    static func listFiles(query: String? = nil) async throws -> [DriveFile] {
        let token = try await getValidAccessToken()

        var components = URLComponents(string: driveFilesURL)!
        var queryItems = [
            URLQueryItem(name: "spaces", value: "appDataFolder"),
            URLQueryItem(name: "fields", value: "files(id,name,modifiedTime,size)"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc"),
            URLQueryItem(name: "pageSize", value: "1000"),
        ]
        if let query { queryItems.append(URLQueryItem(name: "q", value: query)) }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await checkedData(for: request)
        let response = try JSONDecoder().decode(DriveFileListResponse.self, from: data)
        return response.files
    }

    /// Upload a file to appDataFolder.
    static func uploadFile(name: String, data: Data, existingFileId: String? = nil) async throws -> String {
        let token = try await getValidAccessToken()

        let boundary = UUID().uuidString
        var body = Data()

        // Metadata part
        let metadata: [String: Any]
        if existingFileId != nil {
            metadata = ["name": name]
        } else {
            metadata = ["name": name, "parents": ["appDataFolder"]]
        }
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)

        // File content part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let urlString: String
        if let fileId = existingFileId {
            urlString = "\(driveUploadURL)/\(fileId)?uploadType=multipart"
        } else {
            urlString = "\(driveUploadURL)?uploadType=multipart"
        }

        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = existingFileId != nil ? "PATCH" : "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let responseData = try await checkedData(for: request)
        let file = try JSONDecoder().decode(DriveFile.self, from: responseData)
        return file.id
    }

    /// Download a file's content by ID.
    static func downloadFile(fileId: String) async throws -> Data {
        let token = try await getValidAccessToken()

        var components = URLComponents(string: "\(driveFilesURL)/\(fileId)")!
        components.queryItems = [URLQueryItem(name: "alt", value: "media")]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await checkedData(for: request)
        return data
    }

    /// Delete a file by ID.
    static func deleteFile(fileId: String) async throws {
        let token = try await getValidAccessToken()

        var request = URLRequest(url: URL(string: "\(driveFilesURL)/\(fileId)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let _ = try await checkedData(for: request)
    }

    // MARK: - Sync Operations

    /// Push change events as a new immutable batch file on Drive.
    static func pushChangeEvents(_ events: [ChangeEvent]) async throws {
        guard !events.isEmpty else { return }
        let encoder = JSONEncoder()
        let lines = try events.map { try encoder.encode($0) }
        let ndjson = lines.map { String(data: $0, encoding: .utf8)! }.joined(separator: "\n")
        let data = ndjson.data(using: .utf8)!
        let batchName = "batch-\(UUID().uuidString).ndjson"
        _ = try await uploadFile(name: batchName, data: data)
    }

    /// Pull change events from all batch files, optionally filtering by modification date.
    static func pullChangeEvents(since: Date?) async throws -> [ChangeEvent] {
        var files = try await listFiles(query: "name contains 'batch-'")

        if let since {
            let formatter = ISO8601DateFormatter()
            files = files.filter { file in
                guard let modTime = file.modifiedTime,
                      let date = formatter.date(from: modTime) else { return true }
                return date > since
            }
        }

        let decoder = JSONDecoder()
        var allEvents: [ChangeEvent] = []
        for file in files {
            let data = try await downloadFile(fileId: file.id)
            for line in data.split(separator: UInt8(ascii: "\n")) {
                if let event = try? decoder.decode(ChangeEvent.self, from: Data(line)) {
                    allEvents.append(event)
                }
            }
        }
        return allEvents.sorted { $0.timestamp < $1.timestamp }
    }

    /// Upload a compacted snapshot and clean up old batch and snapshot files.
    static func compact(snapshotData: Data) async throws {
        // Upload new snapshot
        let existingSnapshots = try await listFiles(query: "name contains 'snapshot-'")
        let snapshotName = "snapshot-\(ISO8601DateFormatter().string(from: Date())).json"
        _ = try await uploadFile(name: snapshotName, data: snapshotData)

        // Delete all batch files
        let batches = try await listFiles(query: "name contains 'batch-'")
        for batch in batches {
            try? await deleteFile(fileId: batch.id)
        }

        // Delete old snapshots
        for old in existingSnapshots {
            try? await deleteFile(fileId: old.id)
        }
    }

    // MARK: - Build SyncClient

    static func makeSyncClient() -> SyncClient {
        SyncClient(
            authenticate: { try await authenticate() },
            isAuthenticated: { isAuthenticated },
            signOut: { deleteRefreshToken() },
            pushBatch: { events in try await pushChangeEvents(events) },
            pullEvents: { since in try await pullChangeEvents(since: since) },
            compact: { data in try await compact(snapshotData: data) }
        )
    }
}

// MARK: - Models

struct TokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
    let token_type: String
}

struct DriveFile: Codable {
    let id: String
    let name: String
    var modifiedTime: String?
    var size: String?
}

struct DriveFileListResponse: Codable {
    let files: [DriveFile]
}

// MARK: - PKCE Helpers

private func generateCodeVerifier() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func generateCodeChallenge(from verifier: String) -> String {
    let data = Data(verifier.utf8)
    let hash = SHA256.hash(data: data)
    return Data(hash).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

// MARK: - Token Manager (Actor)

private actor TokenManager {
    var accessToken: String?
    var accessTokenExpiry: Date?
    var refreshTask: Task<String, Error>?

    func getValidToken(refreshing: @Sendable @escaping () async throws -> Void) async throws -> String {
        if let token = accessToken, let expiry = accessTokenExpiry, expiry > Date() {
            return token
        }
        // Coalesce concurrent refresh requests
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task<String, Error> {
            try await refreshing()
            guard let token = accessToken else {
                throw SyncError.notAuthenticated
            }
            return token
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    func setToken(_ response: TokenResponse) {
        accessToken = response.access_token
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(response.expires_in - 60))
    }

    func clear() {
        accessToken = nil
        accessTokenExpiry = nil
    }
}

// MARK: - ASWebAuthenticationSession Context

@MainActor
class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()
    var currentSession: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
