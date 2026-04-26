import AppKit
import Darwin

private func diLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) \(message)\n"
    guard let fp = fopen("/tmp/dynamic-island.log", "a") else { return }
    fputs(line, fp)
    fclose(fp)
}

final class NotchOverlay {
    private var window: NSWindow?
    private var spaceObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var timer: Timer?

    func refresh(showsDebugColor: Bool) {
        guard showsDebugColor,
              let screen = NSScreen.main,
              ScreenGeometry.shouldReserveSpace(for: screen) else {
            teardown()
            return
        }
        installObserversIfNeeded()
        evaluate()
    }

    func teardown() {
        timer?.invalidate()
        timer = nil
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
            self.spaceObserver = nil
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        window?.orderOut(nil)
        window = nil
    }

    private func installObserversIfNeeded() {
        if spaceObserver == nil {
            spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                diLog("[DynamicIsland] activeSpaceDidChange")
                self?.evaluate(reason: "spaceChange")
            }
        }
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                diLog("[DynamicIsland] didChangeScreenParameters")
                self?.evaluate(reason: "screenParams")
            }
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.evaluate(reason: "timer")
            }
        }
    }

    private func evaluate(reason: String = "manual") {
        guard let screen = NSScreen.main,
              ScreenGeometry.shouldReserveSpace(for: screen) else {
            diLog("[DynamicIsland] evaluate(\(reason)): no eligible screen, orderOut")
            window?.orderOut(nil)
            return
        }
        let inset = screen.frame.maxY - screen.visibleFrame.maxY
        let menuBarVisible = inset > 0.5
        diLog("[DynamicIsland] evaluate(\(reason)): frame=\(screen.frame) visibleFrame=\(screen.visibleFrame) inset=\(inset) menuBarVisible=\(menuBarVisible)")
        guard menuBarVisible else {
            window?.orderOut(nil)
            return
        }
        present(frame: ScreenGeometry.notchFrame(on: screen))
    }

    private func present(frame: NSRect) {
        let w = window ?? makeWindow(frame: frame)
        window = w
        w.setFrame(frame, display: true)
        w.contentView?.layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.75).cgColor
        w.orderFrontRegardless()
    }

    private func makeWindow(frame: NSRect) -> NSWindow {
        let w = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary]
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.ignoresMouseEvents = true
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        w.contentView = view
        return w
    }
}
