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
        case revealing(start: Date, fromFraction: Double, duration: TimeInterval)
        case visible
        case concealing(start: Date, fromFraction: Double, duration: TimeInterval)
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
            startReveal(from: currentReveal, reason: reason)
        } else {
            startConceal(from: currentReveal, reason: reason)
        }
    }

    private func startReveal(from: Double, reason: String) {
        // Proportional duration: a half-completed reveal takes half the time so
        // the bar moves at consistent peak velocity rather than re-decelerating
        // through the full ease-in-out from a partial position.
        let duration = Self.animationDuration * (1.0 - from)
        state = .revealing(start: Date(), fromFraction: from, duration: duration)
        diLog("[AnimTracker] reveal from=\(from) dur=\(duration) (\(reason))")
    }

    private func startConceal(from: Double, reason: String) {
        let duration = Self.animationDuration * from
        state = .concealing(start: Date(), fromFraction: from, duration: duration)
        diLog("[AnimTracker] conceal from=\(from) dur=\(duration) (\(reason))")
    }

    // MARK: - Mouse handling

    private func handleMouseMoved() {
        guard mode == .autoHide else { return }
        let inZone = cursorInTriggerZone()
        switch state {
        case .hidden:
            if inZone {
                startReveal(from: 0, reason: "hover")
            }
        case .concealing:
            if inZone {
                startReveal(from: currentReveal, reason: "hover-interrupts-conceal")
            }
        case .revealing:
            // Cursor left while bar was revealing — reverse so we don't fully reveal
            // on a quick graze and then sit there for the full hide-delay.
            if !inZone {
                startConceal(from: currentReveal, reason: "leave-during-reveal")
            }
        case .visible:
            if inZone {
                // Cursor re-entered while visible; reset hide timer.
                scheduleHide()
            }
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
        startConceal(from: 1.0, reason: "hide-timer")
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
        case .revealing(let start, _, let duration):
            if now.timeIntervalSince(start) >= duration {
                state = .visible
                if mode == .autoHide {
                    scheduleHide()
                }
            }
        case .concealing(let start, _, let duration):
            if now.timeIntervalSince(start) >= duration {
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
        case .revealing(let start, let from, let duration):
            let t = duration > 0 ? min(now.timeIntervalSince(start) / duration, 1.0) : 1.0
            return from + (1.0 - from) * Self.easeInOut(t)
        case .concealing(let start, let from, let duration):
            let t = duration > 0 ? min(now.timeIntervalSince(start) / duration, 1.0) : 1.0
            return from * (1.0 - Self.easeInOut(t))
        }
    }

    /// Cubic Bezier ease-in-out matching `CAMediaTimingFunction(name: .easeInEaseOut)`
    /// (control points (0.42, 0) and (0.58, 1)). Solves the parametric Bezier for the
    /// y-value at the given x via Newton-Raphson.
    private static func easeInOut(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }

        let cx1 = 0.42, cy1 = 0.0
        let cx2 = 0.58, cy2 = 1.0

        // Find Bezier parameter t such that X(t) = x.
        var t = x  // initial guess; sufficient for monotonic curves
        for _ in 0..<8 {
            let xt = 3 * (1 - t) * (1 - t) * t * cx1
                   + 3 * (1 - t) * t * t * cx2
                   + t * t * t
            let dxdt = 3 * (1 - t) * (1 - t) * cx1
                     + 6 * (1 - t) * t * (cx2 - cx1)
                     + 3 * t * t * (1 - cx2)
            if abs(dxdt) < 1e-6 { break }
            let next = t - (xt - x) / dxdt
            if abs(next - t) < 1e-5 { t = next; break }
            t = next
        }

        return 3 * (1 - t) * (1 - t) * t * cy1
             + 3 * (1 - t) * t * t * cy2
             + t * t * t
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
