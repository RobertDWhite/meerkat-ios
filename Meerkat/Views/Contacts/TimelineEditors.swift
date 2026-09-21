import SwiftUI

// Small modal editors for the things you add to a contact from your phone:
// notes, activities, reminders and relationships.

struct NoteEditorView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let contactId: Int
    let note: Note?

    @State private var content = ""
    @State private var date = Date()
    @State private var saving = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        Form {
            if let error { ErrorBanner(message: error) }
            Section {
                TextField("What happened?", text: $content, axis: .vertical)
                    .lineLimit(4...12)
                    .focused($focused)
            }
            Section { DatePicker("Date", selection: $date, displayedComponents: .date) }
        }
        .navigationTitle(note == nil ? "New note" : "Edit note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            if let note { content = note.content; date = note.date }
            focused = true
        }
    }

    private func save() async {
        saving = true
        do {
            if let note {
                try await APIClient.shared.updateNote(note.id, contactId: contactId, content: content, date: date)
            } else {
                try await APIClient.shared.addNote(to: contactId, content: content, date: date)
            }
            state.contactsChanged()
            dismiss()
        } catch { self.error = describe(error) }
        saving = false
    }
}

struct ActivityEditorView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let contactId: Int

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var date = Date()
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        Form {
            if let error { ErrorBanner(message: error) }
            Section {
                TextField("Title (e.g. Coffee, Call)", text: $title)
                TextField("Location", text: $location)
                DatePicker("Date", selection: $date)
            }
            Section("Details") {
                TextField("Description", text: $description, axis: .vertical).lineLimit(3...10)
            }
        }
        .navigationTitle("New activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() async {
        saving = true
        do {
            try await APIClient.shared.addActivity(ActivityInput(
                title: title, description: description, location: location, date: date, contactIds: [contactId]))
            state.contactsChanged()
            dismiss()
        } catch { self.error = describe(error) }
        saving = false
    }
}

struct ReminderEditorView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let contactId: Int

    @State private var message = ""
    @State private var remindAt = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var recurrence: Recurrence = .once
    @State private var byMail = false
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        Form {
            if let error { ErrorBanner(message: error) }
            Section {
                TextField("Remind me to…", text: $message, axis: .vertical)
                DatePicker("When", selection: $remindAt, displayedComponents: .date)
                Picker("Repeat", selection: $recurrence) {
                    ForEach(Recurrence.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Also send by email", isOn: $byMail)
            }
        }
        .navigationTitle("New reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || message.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() async {
        saving = true
        do {
            try await APIClient.shared.addReminder(ReminderInput(
                message: message, byMail: byMail, remindAt: remindAt,
                recurrence: recurrence.rawValue, contactId: contactId))
            state.contactsChanged()
            dismiss()
        } catch { self.error = describe(error) }
        saving = false
    }
}

struct RelationshipEditorView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let contactId: Int

    @State private var name = ""
    @State private var type = ""
    @State private var birthday = ""
    @State private var linked: Contact?
    @State private var showPicker = false
    @State private var saving = false
    @State private var error: String?

    private let suggestions = ["Partner", "Spouse", "Child", "Parent", "Sibling", "Friend", "Colleague", "Manager"]

    var body: some View {
        Form {
            if let error { ErrorBanner(message: error) }
            Section {
                HStack {
                    TextField("Name", text: $name)
                    Button { showPicker = true } label: { Image(systemName: "person.crop.circle.badge.plus") }
                        .buttonStyle(.borderless)
                }
                if let linked { Label("Linked to \(linked.fullName)", systemImage: "link").font(.caption).foregroundStyle(.secondary) }
                TextField("Relationship (e.g. Spouse)", text: $type)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) { type = s }.buttonStyle(.bordered).font(.caption)
                        }
                    }
                }
                TextField("Birthday (optional, YYYY-MM-DD)", text: $birthday)
            }
        }
        .navigationTitle("New relationship")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || name.isEmpty || type.isEmpty)
            }
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                ContactPickerView(exclude: contactId) { c in
                    linked = c
                    if name.isEmpty { name = c.fullName }
                }
            }
        }
    }

    private func save() async {
        saving = true
        do {
            try await APIClient.shared.addRelationship(to: contactId, RelationshipInput(
                name: name, type: type, birthday: birthday, relatedContactId: linked?.id))
            state.contactsChanged()
            dismiss()
        } catch { self.error = describe(error) }
        saving = false
    }
}

/// Searchable list for choosing an existing contact.
struct ContactPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var exclude: Int?
    var onPick: (Contact) -> Void

    @State private var search = ""
    @State private var results: [Contact] = []

    var body: some View {
        List(results.filter { $0.id != exclude }) { c in
            Button { onPick(c); dismiss() } label: { ContactRow(contact: c) }
                .foregroundStyle(.primary)
        }
        .searchable(text: $search)
        .navigationTitle("Choose contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .task { await load() }
        .onChange(of: search) { Task { await load() } }
    }

    private func load() async {
        results = (try? await APIClient.shared.contacts(search: search))?.items ?? []
    }
}
