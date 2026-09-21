import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if state.isConfigured {
            TabView {
                ContactListView()
                    .tabItem { Label("Contacts", systemImage: "person.2") }
                RemindersView()
                    .tabItem { Label("Reminders", systemImage: "bell") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        } else {
            OnboardingView()
        }
    }
}
