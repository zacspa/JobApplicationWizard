import Foundation
import ComposableArchitecture

public struct AppVersionClient {
    public var currentVersion: @Sendable () -> String

    public init(currentVersion: @escaping @Sendable () -> String) {
        self.currentVersion = currentVersion
    }
}

extension AppVersionClient: DependencyKey {
    public static let liveValue = AppVersionClient(
        currentVersion: {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                ?? "1.0"
        }
    )
}

extension AppVersionClient: TestDependencyKey {
    public static let testValue = AppVersionClient(
        currentVersion: { "0.0" }
    )
}

extension DependencyValues {
    public var appVersionClient: AppVersionClient {
        get { self[AppVersionClient.self] }
        set { self[AppVersionClient.self] = newValue }
    }
}
