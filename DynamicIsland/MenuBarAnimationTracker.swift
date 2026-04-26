import AppKit
import Combine

final class MenuBarAnimationTracker {
    typealias FrameCallback = (NSRect?) -> Void

    private enum Mode: Equatable {
        case alwaysVisible   // No auto-hide; menu bar stays put.
        case autoHide        // Auto-hide active (fullscreen .autoHideMenuBar or _HIHideMenuBar=true). Cursor drives reveal.
        case hardHidden      // .hideMenuBar (kiosk-style); menu bar never appears.
    }

    private enum RevealState {
        case hidden
        case revealing(start: Date, fromFraction: Double)
        case visible
        case concealing(start: Date, fromFraction: Double)
    }

    // Tunables — empirically derived from the system menu bar slide animation on
    // macOS Sonoma/Sequoia. Verify with a 120fps screen recording if visible
    // desync appears on a specific machine.
    private static let animationDuration: TimeInterval = 0.25
    private static let triggerZone: CGFloat = 5.0
    private static let hideDelay: TimeInterval = 3.0

    private let screen: NSScreen
    private let callback: FrameCallback

    private var cancellables: Set<AnyCancellable> = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var displayTimer: Timer?
    private var hideTimer: Timer?

    private var mode: Mode = .alwaysVisible
    private var state: RevealState = .visible
    private var currentReveal: Double = 1.0
    private var lastEmitted: NSRect?
    private var lastEmittedHidden = false

    init(screen: NSScreen, callback: @escaping FrameCallback) {
        self.screen = screen
        self.callback = callback
    }

    func start() {
        observePresentationOptions()
        observeUserDefaults()
        observeWorkspaceNotifications()
        installMouseMonitors()
        evaluateMode(reason: "start")
        startDisplayTimer()
        diLog("[AnimTracker] started screen=\(screen.frame)")
    }

    func stop() {
        cancellables.removeAll()
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        displayTimer?.invalidate()
        displayTimer = nil
        hideTimer?.invalidate()
        hideTimer = nil
        diLog("[AnimTracker] stopped")
    }

    // MARK: - Observers

    private func observePresentationOptions() {
        NSApp.publisher(for: \.currentSystemPresentationOptions)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.evaluateMode(reason: "presentationOptions") }
            .store(in: &cancellables)
    }

    private func observeUserDefaults() {
        // _HIHideMenuBar (global auto-hide) is read on every evaluate; refresh on
        // suite changes too in case the user toggles it during the session.
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.evaluateMode(reason: "defaultsChanged") }
            .store(in: &cancellables)
    }

    private func observeWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.evaluateMode(reason: "spaceChanged") }
            .store(in: &cancellables)
    }

    private func installMouseMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
    }

    // MARK: - Mode evaluation

    private func evaluateMode(reason: String) {
        let opts = NSApp.currentSystemPresentationOptions
        let globalAutoHide = UserDefaults.standard.bool(forKey: "_HIHideMenuBar")

        let newMode: Mode
        if opts.contains(.hideMenuBar) {
            newMode = .hardHidden
        } else if opts.contains(.autoHideMenuBar) || globalAutoHide {
            newMode = .autoHide
        } else {
            newMode = .alwaysVisible
        }

        guard newMode != mode else { return }
        diLog("[AnimTracker] mode \(mode) → \(newMode) (\(reason))")
        mode = newMode

        switch newMode {
        case .alwaysVisible:
            transitionToward(target: 1.0, reason: "→alwaysVisible")
        case .autoHide:
            // Menu bar will hide; if cursor isn't at the top, animate to hidden.
            if !cursorInTriggerZone() {
                transitionToward(target: 0.0, reason: "→autoHide(no hover)")
            } else {
                transitionToward(target: 1.0, reason: "→autoHide(hovering)")
            }
        case .hardHidden:
            transitionToward(target: 0.0, reason: "→hardHidden")
        }
    }

    private func transitionToward(target: Double, reason: String) {
        if abs(currentReveal - target) < 0.001 { return }
        if target > currentReveal {
            state = .revealing(start: Date(), fromFraction: currentReveal)
        } else {
            state = .concealing(start: Date(), fromFraction: currentReveal)
        }
        diLog("[AnimTracker] anim \(currentReveal) → \(target) (\(reason))")
    }

    // MARK: - Mouse handling

    private func handleMouseMoved() {
        guard mode == .autoHide else { return }
        let inZone = cursorInTriggerZone()
        switch state {
        case .hidden:
            if inZone {
                state = .revealing(start: Date(), fromFraction: 0)
                diLog("[AnimTracker] hover-reveal start")
            }
        case .concealing:
            if inZone {
                state = .revealing(start: Date(), fromFraction: currentReveal)
                diLog("[AnimTracker] hover interrupts conceal at \(currentReveal)")
            }
        case .visible:
            if inZone {
                // Cursor re-entered while visible; reset hide timer.
                scheduleHide()
            }
        case .revealing:
            break
        }
    }

    private func cursorInTriggerZone() -> Bool {
        let mouseY = NSEvent.mouseLocation.y
        return mouseY >= screen.frame.maxY - Self.triggerZone
    }

    // MARK: - Hide timing

    private func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.hideDelay, repeats: false) { [weak self] _ in
            self?.attemptHide()
        }
    }

    private func attemptHide() {
        guard mode == .autoHide else { return }
        guard case .visible = state else { return }
        if cursorInTriggerZone() {
            scheduleHide()  // re-arm; cursor still up there
            return
        }
        state = .concealing(start: Date(), fromFraction: 1.0)
        diLog("[AnimTracker] auto-hide start")
    }

    // MARK: - Per-frame tick

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        displayTimer = t
    }

    private func tick() {
        let now = Date()
        currentReveal = computeReveal(now: now)

        // State completion transitions.
        switch state {
        case .revealing(let start, _):
            if now.timeIntervalSince(start) >= Self.animationDuration {
                state = .visible
                if mode == .autoHide {
                    scheduleHide()
                }
            }
        case .concealing(let start, _):
            if now.timeIntervalSince(start) >= Self.animationDuration {
                state = .hidden
            }
        case .visible, .hidden:
            break
        }

        emit(reveal: currentReveal)
    }

    private func computeReveal(now: Date) -> Double {
        switch state {
        case .hidden:
            return 0.0
        case .visible:
            return 1.0
        case .revealing(let start, let from):
            let t = min(now.timeIntervalSince(start) / Self.animationDuration, 1.0)
            return from + (1.0 - from) * easeInOut(t)
        case .concealing(let start, let from):
            let t = min(now.timeIntervalSince(start) / Self.animationDuration, 1.0)
            return from * (1.0 - easeInOut(t))
        }
    }

    private func easeInOut(_ t: Double) -> Double {
        // Cubic ease-in-out — matches CAMediaTimingFunction(.easeInEaseOut) closely.
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }

    // MARK: - Frame emission

    private func emit(reveal: Double) {
        if reveal < 0.001 {
            if !lastEmittedHidden {
                lastEmittedHidden = true
                lastEmitted = nil
                callback(nil)
            }
            return
        }
        let height = ScreenGeometry.menuBarHeight(of: screen)
        let yOffset = height * (1.0 - reveal)
        let y = screen.frame.maxY - height + yOffset
        let frame = NSRect(x: screen.frame.minX, y: y, width: screen.frame.width, height: height)
        if lastEmittedHidden || lastEmitted != frame {
            lastEmittedHidden = false
            lastEmitted = frame
            callback(frame)
        }
    }
}
