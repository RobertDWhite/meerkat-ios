import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @AppStorage("baseURL") var baseURL: String = ""
    @Published var token: String = Keychain.get("apiToken") ?? ""
    @Published var isConfigured = false
    @Published var user: User?

    /// Bumped whenever a contact is created/updated/deleted so list views can refresh.
    @Published var contactsVersion = 0

    init() {
        Task { await applyConfig() }
    }

    /// Verifies the credentials against `/users/me` before persisting them.
    func saveCredentials(baseURL: String, token: String) async throws {
        await APIClient.shared.configure(baseURLString: baseURL, token: token)
        let me = try await APIClient.shared.me()
        self.baseURL = baseURL
        self.token = token
        Keychain.set(token, for: "apiToken")
        user = me
        isConfigured = true
    }

    func signOut() async {
        token = ""
        user = nil
        Keychain.delete("apiToken")
        await applyConfig()
    }

    func applyConfig() async {
        await APIClient.shared.configure(baseURLString: baseURL, token: token)
        isConfigured = !baseURL.isEmpty && !token.isEmpty
    }

    func contactsChanged() { contactsVersion += 1 }
}
