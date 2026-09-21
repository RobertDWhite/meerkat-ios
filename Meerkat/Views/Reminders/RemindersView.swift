import SwiftUI

/// Open reminders across all contacts plus upcoming birthdays.
struct RemindersView: View {
    @EnvironmentObject private var state: AppState
    @State private var reminders: [Reminder] = []
    @State private var birthdays: [Birthday] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error { Section { ErrorBanner(message: error) } }

                if !birthdays.isEmpty {
                    Section("Upcoming birthdays") {
                        ForEach(birthdays) { b in
                            NavigationLink(value: b.id) {
                                HStack {
                                    Image(systemName: "gift").foregroundStyle(Color.accentColor)
                                    Text(b.fullName)
                                    Spacer()
                                    Text(b.birthday.birthdayDisplay).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section(reminders.isEmpty ? "" : "Reminders") {
                    ForEach(reminders) { r in
                        NavigationLink(value: r.contactId ?? 0) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.message)
                                    HStack(spacing: 6) {
                                        if let c = r.contact { Text(c.fullName).fontWeight(.medium) }
                                        Text(r.remindAt.shortDate)
                                        Text("· " + (Recurrence(rawValue: r.recurrence)?.label ?? r.recurrence))
                                    }
                                    .font(.caption).foregroundStyle(r.remindAt < .now ? .red : .secondary)
                                }
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { try? await APIClient.shared.completeReminder(r.id); await load() }
                            } label: { Label("Done", systemImage: "checkmark") }
                                .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { try? await APIClient.shared.deleteReminder(r.id); await load() }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                if !loading && reminders.isEmpty && birthdays.isEmpty && error == nil {
                    ContentUnavailableView("Nothing due", systemImage: "bell.slash",
                                           description: Text("Reminders you add to contacts show up here."))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reminders")
            .navigationDestination(for: Int.self) { id in ContactDetailView(contactId: id) }
            .overlay { if loading && reminders.isEmpty { ProgressView() } }
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: state.contactsVersion) { Task { await load() } }
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            async let r = APIClient.shared.allReminders()
            async let b = APIClient.shared.upcomingBirthdays()
            reminders = try await r.filter { !$0.completed }.sorted { $0.remindAt < $1.remindAt }
            birthdays = (try? await b) ?? []
        } catch { self.error = describe(error) }
        loading = false
    }
}
