import SwiftUI
import PhotosUI

struct ContactDetailView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let contactId: Int

    @State private var contact: Contact?
    @State private var photo: UIImage?
    @State private var loading = true
    @State private var error: String?

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var photoItem: PhotosPickerItem?
    @State private var noteToEdit: Note?
    @State private var showNewNote = false
    @State private var showNewActivity = false
    @State private var showNewReminder = false
    @State private var showNewRelationship = false

    var body: some View {
        Group {
            if let contact {
                content(contact)
            } else if loading {
                ProgressView()
            } else {
                ContentUnavailableView("Couldn't load contact", systemImage: "person.slash",
                                       description: Text(error ?? ""))
            }
        }
        .navigationTitle(contact?.fullName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let contact {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Change photo", systemImage: "photo")
                        }
                        Divider()
                        Button {
                            Task { await toggleArchive(contact) }
                        } label: {
                            Label(contact.archived ? "Unarchive" : "Archive",
                                  systemImage: contact.archived ? "tray.and.arrow.up" : "archivebox")
                        }
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .task(id: contactId) { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showEdit) {
            if let contact { NavigationStack { ContactEditView(mode: .edit(contact)) } }
        }
        .sheet(isPresented: $showNewNote) {
            NavigationStack { NoteEditorView(contactId: contactId, note: nil) }
        }
        .sheet(item: $noteToEdit) { note in
            NavigationStack { NoteEditorView(contactId: contactId, note: note) }
        }
        .sheet(isPresented: $showNewActivity) {
            NavigationStack { ActivityEditorView(contactId: contactId) }
        }
        .sheet(isPresented: $showNewReminder) {
            NavigationStack { ReminderEditorView(contactId: contactId) }
        }
        .sheet(isPresented: $showNewRelationship) {
            NavigationStack { RelationshipEditorView(contactId: contactId) }
        }
        .onChange(of: state.contactsVersion) { Task { await load() } }
        .onChange(of: photoItem) { Task { await uploadPickedPhoto() } }
        .confirmationDialog("Delete this contact?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteContact() } }
        } message: { Text("This removes the contact and all of its notes, activities and reminders.") }
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(_ c: Contact) -> some View {
        List {
            Section {
                header(c)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if let error { Section { ErrorBanner(message: error) } }

            contactInfoSection(c)
            aboutSection(c)
            customFieldsSection(c)
            notesSection(c)
            activitiesSection(c)
            remindersSection(c)
            relationshipsSection(c)
        }
        .listStyle(.insetGrouped)
    }

    private func header(_ c: Contact) -> some View {
        VStack(spacing: 10) {
            AvatarView(contact: c, size: 96, image: photo)
            Text(c.fullName).font(.title2.bold())
            if !c.nickname.isEmpty { Text("“\(c.nickname)”").foregroundStyle(.secondary) }
            if !c.subtitle.isEmpty { Text(c.subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            if !c.circleList.isEmpty {
                HStack(spacing: 6) {
                    ForEach(c.circleList, id: \.self) { circle in
                        Text(circle).font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
            }
            quickActions(c)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func quickActions(_ c: Contact) -> some View {
        let phone = c.phoneList.first?.value ?? c.phone
        let email = c.emailList.first?.value ?? c.email
        let digits = phone.filter { "+0123456789".contains($0) }
        return HStack(spacing: 12) {
            actionButton("Call", "phone.fill", url: digits.isEmpty ? nil : URL(string: "tel:" + digits))
            actionButton("Message", "message.fill", url: digits.isEmpty ? nil : URL(string: "sms:" + digits))
            actionButton("Email", "envelope.fill", url: email.isEmpty ? nil : URL(string: "mailto:" + email))
        }
        .padding(.top, 4)
    }

    private func actionButton(_ title: String, _ icon: String, url: URL?) -> some View {
        Button {
            if let url { UIApplication.shared.open(url) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.body)
                Text(title).font(.caption2)
            }
            .frame(width: 72, height: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .opacity(url == nil ? 0.4 : 1)
    }

    @ViewBuilder
    private func contactInfoSection(_ c: Contact) -> some View {
        let emails = c.emailList.isEmpty && !c.email.isEmpty ? [TypedValue(type: "", value: c.email)] : c.emailList
        let phones = c.phoneList.isEmpty && !c.phone.isEmpty ? [TypedValue(type: "", value: c.phone)] : c.phoneList
        let addresses = c.addressList.map(\.formatted).filter { !$0.isEmpty }
        let legacyAddress = addresses.isEmpty && !c.address.isEmpty ? [c.address] : addresses
        if !emails.isEmpty || !phones.isEmpty || !legacyAddress.isEmpty || !c.urlList.isEmpty || !c.imppList.isEmpty {
            Section("Contact") {
                ForEach(phones) { ContactValueRow(label: $0.type, value: $0.value, kind: .phone) }
                ForEach(emails) { ContactValueRow(label: $0.type, value: $0.value, kind: .email) }
                ForEach(legacyAddress, id: \.self) { ContactValueRow(label: "address", value: $0, kind: .address) }
                ForEach(c.urlList) { ContactValueRow(label: $0.type, value: $0.value, kind: .url) }
                ForEach(c.imppList) { ContactValueRow(label: $0.type, value: $0.value) }
            }
        }
    }

    @ViewBuilder
    private func aboutSection(_ c: Contact) -> some View {
        let rows: [(String, String)] = [
            ("Birthday", c.birthday.birthdayDisplay),
            ("Anniversary", c.anniversary.birthdayDisplay),
            ("Gender", c.gender.replacingOccurrences(of: "_", with: " ")),
            ("Department", c.department),
            ("Role", c.role),
            ("How we met", c.howWeMet),
            ("Food preference", c.foodPreference),
            ("Work", c.workInformation),
            ("Other contact info", c.contactInformation),
        ].filter { !$0.1.isEmpty }
        if !rows.isEmpty {
            Section("About") {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0).font(.caption).foregroundStyle(.secondary)
                        Text(row.1).textSelection(.enabled)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func customFieldsSection(_ c: Contact) -> some View {
        let fields = c.customFieldList.filter { !$0.value.isEmpty }
        if !fields.isEmpty {
            Section("Custom fields") {
                ForEach(fields, id: \.key) { f in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.key.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption).foregroundStyle(.secondary)
                        Text(f.value).textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func notesSection(_ c: Contact) -> some View {
        Section {
            ForEach((c.notes ?? []).sorted { $0.date > $1.date }) { note in
                Button { noteToEdit = note } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.date.shortDate).font(.caption).foregroundStyle(.secondary)
                        Text(note.content).foregroundStyle(.primary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { try? await APIClient.shared.deleteNote(note.id); await load() }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            Button { showNewNote = true } label: { Label("Add note", systemImage: "plus") }
        } header: { Text("Notes") }
    }

    private func activitiesSection(_ c: Contact) -> some View {
        Section {
            ForEach((c.activities ?? []).sorted { $0.date > $1.date }) { a in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(a.title).fontWeight(.medium)
                        Spacer()
                        Text(a.date.shortDate).font(.caption).foregroundStyle(.secondary)
                    }
                    if !a.location.isEmpty { Label(a.location, systemImage: "mappin").font(.caption).foregroundStyle(.secondary) }
                    if !a.description.isEmpty { Text(a.description).font(.subheadline) }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { try? await APIClient.shared.deleteActivity(a.id); await load() }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            Button { showNewActivity = true } label: { Label("Add activity", systemImage: "plus") }
        } header: { Text("Activities") }
    }

    private func remindersSection(_ c: Contact) -> some View {
        Section {
            ForEach((c.reminders ?? []).filter { !$0.completed }.sorted { $0.remindAt < $1.remindAt }) { r in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.message)
                        Text("\(r.remindAt.shortDate) · \(Recurrence(rawValue: r.recurrence)?.label ?? r.recurrence)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { try? await APIClient.shared.completeReminder(r.id); await load() }
                    } label: { Image(systemName: "checkmark.circle") }
                        .buttonStyle(.borderless)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { try? await APIClient.shared.deleteReminder(r.id); await load() }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            Button { showNewReminder = true } label: { Label("Add reminder", systemImage: "plus") }
        } header: { Text("Reminders") }
    }

    private func relationshipsSection(_ c: Contact) -> some View {
        Section {
            ForEach(c.relationships ?? []) { rel in
                Group {
                    if let related = rel.relatedContactId {
                        NavigationLink(value: related) { relationshipRow(rel) }
                    } else {
                        relationshipRow(rel)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { try? await APIClient.shared.deleteRelationship(contactId: contactId, id: rel.id); await load() }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            Button { showNewRelationship = true } label: { Label("Add relationship", systemImage: "plus") }
        } header: { Text("Relationships") }
    }

    private func relationshipRow(_ rel: Relationship) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rel.name)
            Text(rel.type + (rel.birthday.isEmpty ? "" : " · \(rel.birthday.birthdayDisplay)"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func load() async {
        error = nil
        do {
            let c = try await APIClient.shared.contact(contactId)
            contact = c
            loading = false
            if !c.photo.isEmpty, let data = try? await APIClient.shared.photo(for: contactId) {
                photo = UIImage(data: data)
            } else {
                photo = nil
            }
        } catch {
            self.error = describe(error)
            loading = false
        }
    }

    private func toggleArchive(_ c: Contact) async {
        do {
            if c.archived { try await APIClient.shared.unarchiveContact(c.id) }
            else { try await APIClient.shared.archiveContact(c.id) }
            state.contactsChanged()
        } catch { self.error = describe(error) }
    }

    private func deleteContact() async {
        do {
            try await APIClient.shared.deleteContact(contactId)
            state.contactsChanged()
            dismiss()
        } catch { self.error = describe(error) }
    }

    private func uploadPickedPhoto() async {
        guard let item = photoItem else { return }
        photoItem = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            // Meerkat re-encodes to 400px JPEG server-side; send something reasonably small.
            let side: CGFloat = 1024
            let scale = min(1, side / max(image.size.width, image.size.height))
            let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let resized = UIGraphicsImageRenderer(size: target).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
            guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return }
            try await APIClient.shared.uploadPhoto(for: contactId, jpeg: jpeg)
            state.contactsChanged()
        } catch { self.error = describe(error) }
    }
}
