import SwiftUI

struct ContactListView: View {
    @EnvironmentObject private var state: AppState
    @State private var contacts: [Contact] = []
    @State private var circles: [String] = []
    @State private var selectedCircle = ""
    @State private var search = ""
    @State private var showArchived = false
    @State private var loading = false
    @State private var error: String?
    @State private var showNew = false
    @State private var page = 1
    @State private var total = 0

    private var grouped: [(letter: String, contacts: [Contact])] {
        let dict = Dictionary(grouping: contacts) { c -> String in
            let key = (c.lastname.isEmpty ? c.firstname : c.lastname).uppercased()
            guard let first = key.first, first.isLetter else { return "#" }
            return String(first)
        }
        return dict.keys.sorted().map { (letter: $0, contacts: dict[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !circles.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                circleChip("All", value: "")
                                ForEach(circles, id: \.self) { circleChip($0, value: $0) }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                if let error { Section { ErrorBanner(message: error) } }

                ForEach(grouped, id: \.letter) { group in
                    Section(group.letter) {
                        ForEach(group.contacts) { contact in
                            NavigationLink(value: contact.id) {
                                ContactRow(contact: contact)
                            }
                        }
                    }
                }

                if contacts.count < total {
                    Section {
                        Button("Load more (\(contacts.count) of \(total))") { Task { await load(more: true) } }
                    }
                }
                if !loading && contacts.isEmpty && error == nil {
                    ContentUnavailableView(
                        search.isEmpty ? "No contacts" : "No results",
                        systemImage: "person.slash",
                        description: Text(search.isEmpty ? "Tap + to add your first contact." : "Try another search.")
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Contacts")
            .navigationDestination(for: Int.self) { id in ContactDetailView(contactId: id) }
            .searchable(text: $search, prompt: "Search name, email, phone…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Show archived", isOn: $showArchived)
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                }
            }
            .overlay { if loading && contacts.isEmpty { ProgressView() } }
            .refreshable { await load() }
            .task { await load(); await loadCircles() }
            .onChange(of: search) { Task { await load() } }
            .onChange(of: selectedCircle) { Task { await load() } }
            .onChange(of: showArchived) { Task { await load() } }
            .onChange(of: state.contactsVersion) { Task { await load(); await loadCircles() } }
            .sheet(isPresented: $showNew) {
                NavigationStack { ContactEditView(mode: .create) }
            }
        }
    }

    private func circleChip(_ title: String, value: String) -> some View {
        Button {
            selectedCircle = value
        } label: {
            Text(title)
                .font(.subheadline.weight(selectedCircle == value ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selectedCircle == value ? Color.accentColor : Color(.tertiarySystemFill),
                            in: Capsule())
                .foregroundStyle(selectedCircle == value ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func load(more: Bool = false) async {
        if more { page += 1 } else { page = 1 }
        loading = true
        error = nil
        do {
            let result = try await APIClient.shared.contacts(
                search: search, circle: selectedCircle, page: page, includeArchived: showArchived)
            total = result.total
            let items = showArchived ? result.items : result.items.filter { !$0.archived }
            contacts = more ? contacts + items : items
        } catch {
            self.error = describe(error)
        }
        loading = false
    }

    private func loadCircles() async {
        circles = (try? await APIClient.shared.circles()) ?? []
    }
}

struct ContactRow: View {
    var contact: Contact
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(contact.fullName).fontWeight(.medium)
                    if contact.archived {
                        Text("Archived").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                }
                if !contact.subtitle.isEmpty {
                    Text(contact.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                } else if !contact.nickname.isEmpty {
                    Text("“\(contact.nickname)”").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}
