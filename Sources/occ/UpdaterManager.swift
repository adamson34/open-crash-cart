import AppKit
import Sparkle

/// Persisted user preferences that steer updates.
enum UpdatePreferences {
    /// When true, the user receives dev/beta appcast items (channel `dev`) in addition to stable.
    static let devChannelKey = "OCCReceiveDevBuilds"
    static var receiveDevBuilds: Bool {
        get { UserDefaults.standard.bool(forKey: devChannelKey) }
        set { UserDefaults.standard.set(newValue, forKey: devChannelKey) }
    }
}

/// Wraps Sparkle's updater. Exposes a manual "Check for Updates…" action and routes the
/// dev-builds toggle into Sparkle's channel filter, so opting in delivers `dev`-tagged appcast
/// items and opting out drops back to stable-only.
@MainActor
final class UpdaterManager: NSObject, SPUUpdaterDelegate {
    /// Appcast channel name for pre-release builds (matches `<sparkle:channel>dev</sparkle:channel>`).
    nonisolated static let devChannel = "dev"

    /// Sparkle needs a real, signed `.app` bundle (Info.plist feed + EdDSA key + code signature).
    /// Under `swift run` the executable is a bare Mach-O with none of that, so updates are simply
    /// unavailable in dev — the menu item stays disabled rather than logging Sparkle errors.
    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    // `lazy` so `self` can be the delegate; starting the updater is deferred to `start()`.
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)

    /// Force the lazy controller to initialize and begin its scheduled-check timer.
    func start() { _ = controller }

    /// User-initiated check (shows Sparkle's UI, including "you're up to date").
    func checkForUpdates() { controller.checkForUpdates(nil) }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    // MARK: SPUUpdaterDelegate

    /// Sparkle queries this on every check. Returning the dev channel opts the user into
    /// pre-release items; returning nothing leaves them on the default (stable) channel. Read
    /// straight from UserDefaults (thread-safe) since Sparkle may call this off the main thread.
    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        UserDefaults.standard.bool(forKey: UpdatePreferences.devChannelKey)
            ? [UpdaterManager.devChannel] : []
    }
}
