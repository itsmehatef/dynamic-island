import AppKit
import CoreGraphics

final class MenuBarTracker {
    typealias Handler = (NSRect?) -> Void

    private let screen: NSScreen
    private let handler: Handler
    private var timer: Timer?
    private var consecutiveMissCount = 0
    private var lastResult: NSRect?
    private var didLogCandidates = false

    init(screen: NSScreen, handler: @escaping Handler) {
        self.screen = screen
        self.handler = handler
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastResult = nil
        consecutiveMissCount = 0
    }

    private func tick() {
        let result = findMenuBarRect()
        if result == nil {
            consecutiveMissCount += 1
            // Debounce: only signal hidden after 3 consecutive misses (~50ms at 60Hz).
            if consecutiveMissCount == 3, lastResult != nil {
                diLog("[MenuBarTracker] menu bar gone (3 misses) → hide")
                lastResult = nil
                handler(nil)
            }
        } else {
            consecutiveMissCount = 0
            if result != lastResult {
                if lastResult == nil {
                    diLog("[MenuBarTracker] menu bar appeared at \(result!)")
                }
                lastResult = result
                handler(result)
            }
        }
    }

    private func findMenuBarRect() -> NSRect? {
        guard let infoList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        if !didLogCandidates {
            logCandidates(infoList)
            didLogCandidates = true
        }

        let primaryHeight = MenuBarTracker.primaryDisplayHeight()
        let targetTopInCG = primaryHeight - screen.frame.maxY

        var bestMatch: CGRect?
        var bestDistance: CGFloat = .infinity

        for info in infoList {
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner == "Window Server" || owner == "WindowServer" else {
                continue
            }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 24 else {
                continue
            }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }
            // Align with target screen's left edge (handles multi-display layouts).
            guard abs(bounds.origin.x - screen.frame.minX) < 4 else { continue }
            // Span (most of) the target screen's width.
            guard abs(bounds.width - screen.frame.width) < 4 else { continue }
            // Menu bar height range (24pt standard, ~38pt notched).
            guard bounds.height >= 20, bounds.height <= 60 else { continue }

            let distance = abs(bounds.origin.y - targetTopInCG)
            if distance < bestDistance {
                bestDistance = distance
                bestMatch = bounds
            }
        }

        guard let cgRect = bestMatch else { return nil }
        let appKitRect = cgRectToAppKit(cgRect, primaryHeight: primaryHeight)
        return isOnScreen(appKitRect) ? appKitRect : nil
    }

    private func cgRectToAppKit(_ cgRect: CGRect, primaryHeight: CGFloat) -> NSRect {
        // CGWindow: top-left origin, y increases downward, relative to primary display.
        // AppKit: bottom-left origin, y increases upward, relative to primary display.
        let y = primaryHeight - cgRect.origin.y - cgRect.height
        return NSRect(x: cgRect.origin.x, y: y, width: cgRect.width, height: cgRect.height)
    }

    private func isOnScreen(_ rect: NSRect) -> Bool {
        // The bar is at least partially visible if its bottom edge is below the
        // screen's top. When fully slid up, minY == screen.frame.maxY.
        rect.minY < screen.frame.maxY - 1
    }

    private static func primaryDisplayHeight() -> CGFloat {
        for screen in NSScreen.screens where screen.frame.origin == .zero {
            return screen.frame.height
        }
        return NSScreen.main?.frame.height ?? 0
    }

    private func logCandidates(_ infoList: [[String: Any]]) {
        diLog("[MenuBarTracker] === Phase 1: Window Server window candidates ===")
        diLog("[MenuBarTracker] target screen.frame=\(screen.frame) primaryHeight=\(MenuBarTracker.primaryDisplayHeight())")
        for info in infoList {
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner.localizedCaseInsensitiveContains("server") else {
                continue
            }
            let layer = info[kCGWindowLayer as String] ?? "?"
            let name = info[kCGWindowName as String] ?? "(no name)"
            var boundsStr = "?"
            if let d = info[kCGWindowBounds as String] as? NSDictionary,
               let r = CGRect(dictionaryRepresentation: d) {
                boundsStr = "\(r)"
            }
            diLog("[MenuBarTracker]   owner=\(owner) layer=\(layer) name=\(name) bounds=\(boundsStr)")
        }
        diLog("[MenuBarTracker] === end Phase 1 ===")
    }
}
