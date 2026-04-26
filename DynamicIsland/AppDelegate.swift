import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var isActive = false

    private let blocker = NotchBlocker()
    private let overlay = NotchOverlay()
    private var screenChangeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        refresh()

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        blocker.teardown()
        overlay.teardown()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func refresh() {
        let debug = UserDefaults.standard.bool(forKey: ScreenGeometry.forceSpacerDefaultsKey)
        blocker.refresh()
        overlay.refresh(showsDebugColor: debug)
        isActive = blocker.isActive
    }
}
