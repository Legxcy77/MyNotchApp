import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginService {
    public init() {}

    public var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    public var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    public var isEnabled: Bool {
        status == .enabled
    }

    public func toggle() throws {
        if isEnabled {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }
}
