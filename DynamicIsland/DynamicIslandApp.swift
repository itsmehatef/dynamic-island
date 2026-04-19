import SwiftUI

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Dynamic Island", systemImage: "rectangle.tophalf.filled") {
            MenuContent(delegate: appDelegate)
        }
        .menuBarExtraStyle(.menu)
    }
}
