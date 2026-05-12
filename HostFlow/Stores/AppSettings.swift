import Foundation
import Observation
import ServiceManagement
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

enum LaunchAtLoginAlert: Identifiable, Equatable {
    case registrationFailed(String)
    case requiresApproval

    var id: String {
        switch self {
        case .registrationFailed: "registrationFailed"
        case .requiresApproval:   "requiresApproval"
        }
    }
}

@Observable
final class AppSettings {

    var appearanceMode: AppearanceMode = .system {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
    }

    var preferredColorScheme: ColorScheme? { appearanceMode.colorScheme }

    var launchAtLogin: Bool = false {
        didSet {
            guard !isSyncingLaunchAtLogin else { return }
            applyLaunchAtLogin()
        }
    }

    var launchAtLoginAlert: LaunchAtLoginAlert?

    private var isSyncingLaunchAtLogin = false

    let helperInstaller: HelperInstaller = .shared

    var helperStatus: HelperStatus { helperInstaller.status }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        }
        syncLaunchAtLoginFromSystem()
    }

    func syncLaunchAtLoginFromSystem() {
        isSyncingLaunchAtLogin = true
        defer { isSyncingLaunchAtLogin = false }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    launchAtLoginAlert = .requiresApproval
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginAlert = .registrationFailed(error.localizedDescription)
        }
        syncLaunchAtLoginFromSystem()
    }
}
