import Foundation
import ComposableArchitecture

// MARK: - Registry Types

public struct ACPAgentEntry: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let authors: [String]
    public let distribution: ACPDistribution
    public let repository: String?
    public let license: String?
    public let icon: String?

    public init(
        id: String,
        name: String,
        version: String,
        description: String,
        authors: [String],
        distribution: ACPDistribution,
        repository: String? = nil,
        license: String? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.authors = authors
        self.distribution = distribution
        self.repository = repository
        self.license = license
        self.icon = icon
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, version, description, authors, distribution, repository, license, icon
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        name         = try c.decode(String.self, forKey: .name)
        version      = try c.decode(String.self, forKey: .version)
        description  = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        authors      = try c.decodeIfPresent([String].self, forKey: .authors) ?? []
        distribution = try c.decode(ACPDistribution.self, forKey: .distribution)
        repository   = try c.decodeIfPresent(String.self, forKey: .repository)
        license      = try c.decodeIfPresent(String.self, forKey: .license)
        icon         = try c.decodeIfPresent(String.self, forKey: .icon)
    }
}

public struct ACPDistribution: Codable, Equatable {
    /// Binary distributions keyed by platform (e.g. "darwin-aarch64")
    public let binary: [String: ACPBinaryEntry]?
    public let npx: ACPNpx?
    public let uvx: ACPUvx?

    public init(binary: [String: ACPBinaryEntry]? = nil, npx: ACPNpx? = nil, uvx: ACPUvx? = nil) {
        self.binary = binary
        self.npx = npx
        self.uvx = uvx
    }
}

public struct ACPBinaryEntry: Codable, Equatable {
    public let archive: String
    public let cmd: String

    public init(archive: String, cmd: String) {
        self.archive = archive
        self.cmd = cmd
    }
}

public struct ACPNpx: Codable, Equatable {
    public let package: String
    public let args: [String]?

    public init(package: String, args: [String]? = nil) {
        self.package = package
        self.args = args
    }
}

public struct ACPUvx: Codable, Equatable {
    public let package: String
    public let args: [String]?

    public init(package: String, args: [String]? = nil) {
        self.package = package
        self.args = args
    }
}

// MARK: - Registry Response

private struct RegistryResponse: Decodable {
    let agents: [ACPAgentEntry]
}

// MARK: - ACPRegistryClient Dependency

public struct ACPRegistryClient {
    public var fetchAgents: @Sendable () async throws -> [ACPAgentEntry]

    public init(fetchAgents: @escaping @Sendable () async throws -> [ACPAgentEntry]) {
        self.fetchAgents = fetchAgents
    }
}

extension ACPRegistryClient: DependencyKey {
    public static var liveValue: ACPRegistryClient {
        ACPRegistryClient(
            fetchAgents: {
                let url = URL(string: "https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json")!
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw ACPRegistryError.fetchFailed
                }
                let registry = try JSONDecoder().decode(RegistryResponse.self, from: data)
                return registry.agents
            }
        )
    }
}

extension ACPRegistryClient: TestDependencyKey {
    public static let testValue = ACPRegistryClient(
        fetchAgents: unimplemented("\(Self.self).fetchAgents", placeholder: [])
    )

    public static let mockValue = ACPRegistryClient(
        fetchAgents: {
            [
                ACPAgentEntry(
                    id: "mock-agent",
                    name: "Mock Agent",
                    version: "1.0.0",
                    description: "A mock agent for testing",
                    authors: ["Test Author"],
                    distribution: ACPDistribution(npx: ACPNpx(package: "mock-agent"))
                )
            ]
        }
    )
}

extension DependencyValues {
    public var acpRegistryClient: ACPRegistryClient {
        get { self[ACPRegistryClient.self] }
        set { self[ACPRegistryClient.self] = newValue }
    }
}

public enum ACPRegistryError: LocalizedError {
    case fetchFailed

    public var errorDescription: String? {
        switch self {
        case .fetchFailed: return "Failed to fetch ACP agent registry."
        }
    }
}
