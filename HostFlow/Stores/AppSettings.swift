import Foundation
import Observation
import ServiceManagement
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var labelKey: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.system"
        case .light:  "settings.appearance.light"
        case .dark:   "settings.appearance.dark"
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

enum PreferredLanguage: String, CaseIterable, Identifiable {
    case system, en, it
    var id: String { rawValue }
    var labelKey: LocalizedStringKey {
        switch self {
        case .system: "settings.language.system"
        case .en:     "settings.language.en"
        case .it:     "settings.language.it"
        }
    }

    var locale: Locale? {
        switch self {
        case .system: nil
        case .en:     Locale(identifier: "en")
        case .it:     Locale(identifier: "it")
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

    var preferredLanguage: PreferredLanguage = .system {
        didSet { UserDefaults.standard.set(preferredLanguage.rawValue, forKey: "preferredLanguage") }
    }

    var resolvedLocale: Locale { preferredLanguage.locale ?? Locale.current }

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
        if let raw = UserDefaults.standard.string(forKey: "preferredLanguage"),
           let lang = PreferredLanguage(rawValue: raw) {
            preferredLanguage = lang
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
