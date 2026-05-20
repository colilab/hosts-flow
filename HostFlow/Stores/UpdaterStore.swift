import Foundation
import Observation
import Sparkle

/// Thin `@Observable` wrapper around Sparkle's standard updater so SwiftUI views
/// can drive a "Check for Updates…" action and an automatic-check toggle without
/// importing Sparkle directly. The controller is created with `startingUpdater: true`,
/// which also arms the scheduled background check configured in `Info.plist`.
@Observable
final class UpdaterStore {

    /// Mirrors `SPUUpdater.canCheckForUpdates` — false while a check is in flight.
    var canCheckForUpdates = false

    @ObservationIgnored
    private let controller: SPUStandardUpdaterController

    @ObservationIgnored
    private var canCheckObservation: NSKeyValueObservation?

    private var updater: SPUUpdater { controller.updater }

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckForUpdates = controller.updater.canCheckForUpdates
        // Sparkle posts this KVO change on the main thread.
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.new]
        ) { [weak self] updater, _ in
            self?.canCheckForUpdates = updater.canCheckForUpdates
        }
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    /// Two-way bound by the Settings toggle; Sparkle persists the value itself.
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }
}
