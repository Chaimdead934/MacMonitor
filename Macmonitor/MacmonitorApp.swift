import SwiftUI

@main
struct MacMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // No window — this is a menu bar only app
        Settings { EmptyView() }
    }
}
