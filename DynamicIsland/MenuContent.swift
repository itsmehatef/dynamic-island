import SwiftUI

struct MenuContent: View {
    @ObservedObject var delegate: AppDelegate
    @AppStorage(ScreenGeometry.forceSpacerDefaultsKey) private var forceSpacerForDebugging = false

    var body: some View {
        Text(statusText)

        Divider()

        Toggle("Force spacer for debugging", isOn: Binding(
            get: { forceSpacerForDebugging },
            set: { newValue in
                forceSpacerForDebugging = newValue
                delegate.refresh()
            }
        ))

        Divider()

        Button("Quit Dynamic Island") {
            delegate.quit()
        }
        .keyboardShortcut("q")
    }

    private var statusText: String {
        if forceSpacerForDebugging {
            return delegate.isActive
                ? "Notch blocker: Forced"
                : "Inactive — no display detected"
        }

        return delegate.isActive
            ? "Notch blocker: Active"
            : "Inactive — no notch detected"
    }
}
