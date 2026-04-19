import SwiftUI

struct MenuContent: View {
    @ObservedObject var delegate: AppDelegate

    var body: some View {
        Text(delegate.isActive
             ? "Notch blocker: Active"
             : "Inactive — no notch detected")

        Divider()

        Button("Quit Dynamic Island") {
            delegate.quit()
        }
        .keyboardShortcut("q")
    }
}
