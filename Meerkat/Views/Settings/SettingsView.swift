import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var baseURL = ""
    @State private var token = ""
    @State private var status: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("https://meerkat.example.com", text: $baseURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("API token (meerkat_…)", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(busy ? "Testing…" : "Save & test connection") { Task { await save() } }
                        .disabled(busy || baseURL.isEmpty || token.isEmpty)
                    if let status { Text(status).font(.footnote).foregroundStyle(.secondary) }
                }
                if let user = state.user {
                    Section("Signed in") {
                        LabeledContent("User", value: user.username)
                        LabeledContent("Email", value: user.email)
                    }
                }
                Section {
                    Button("Sign out", role: .destructive) { Task { await state.signOut() } }
                } footer: {
                    Text("Create an API token in Meerkat → Settings → API Tokens. It is stored in the iOS Keychain.")
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    Link("Meerkat CRM (server)", destination: URL(string: "https://github.com/fbuchner/meerkat-crm")!)
                    Link("Meerkat iOS on GitHub", destination: URL(string: "https://github.com/RobertDWhite/meerkat-ios")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear { baseURL = state.baseURL; token = state.token }
        }
    }

    private func save() async {
        busy = true
        status = nil
        do {
            try await state.saveCredentials(baseURL: baseURL, token: token)
            status = "Connected as \(state.user?.username ?? "?")."
        } catch {
            status = "Failed: \(describe(error))"
        }
        busy = false
    }
}

/// First-run screen shown until a server + token are saved.
struct OnboardingView: View {
    @EnvironmentObject private var state: AppState
    @State private var baseURL = ""
    @State private var token = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Meerkat").font(.largeTitle.bold())
                        Text("A personal CRM in your pocket. Point the app at your self-hosted Meerkat server and paste an API token.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                Section {
                    TextField("https://meerkat.example.com", text: $baseURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("API token", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("Server") } footer: {
                    Text("Meerkat → Settings → API Tokens → Create. The token is shown once.")
                }
                if let error { Section { ErrorBanner(message: error) } }
                Section {
                    Button(busy ? "Connecting…" : "Connect") { Task { await connect() } }
                        .disabled(busy || baseURL.isEmpty || token.isEmpty)
                }
            }
        }
    }

    private func connect() async {
        busy = true
        error = nil
        do { try await state.saveCredentials(baseURL: baseURL, token: token) }
        catch {
            self.error = describe(error)
            await state.signOut()
        }
        busy = false
    }
}
