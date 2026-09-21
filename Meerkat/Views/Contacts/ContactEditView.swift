import SwiftUI

struct ContactEditView: View {
    enum Mode { case create, edit(Contact) }

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var input = ContactInput()
    @State private var circlesText = ""
    @State private var customFields: [KeyValue] = []
    @State private var knownCircles: [String] = []
    @State private var saving = false
    @State private var error: String?

    struct KeyValue: Identifiable { let id = UUID(); var key: String; var value: String }

    private var isNew: Bool { if case .create = mode { return true } else { return false } }

    var body: some View {
        Form {
            if let error { ErrorBanner(message: error) }

            Section("Name") {
                TextField("First name", text: $input.firstname).textContentType(.givenName)
                TextField("Last name", text: $input.lastname).textContentType(.familyName)
                TextField("Nickname", text: $input.nickname).textContentType(.nickname)
                Picker("Gender", selection: $input.gender) {
                    Text("—").tag("")
                    Text("Female").tag("female")
                    Text("Male").tag("male")
                    Text("Other").tag("other")
                    Text("Prefer not to say").tag("prefer_not_to_say")
                }
            }

            Section("Work") {
                TextField("Organization", text: $input.organization).textContentType(.organizationName)
                TextField("Job title", text: $input.jobTitle).textContentType(.jobTitle)
                TextField("Department", text: $input.department)
                TextField("Role", text: $input.role)
            }

            TypedListSection(title: "Phones", items: $input.phones, placeholder: "+1 555 123 4567",
                             types: ["mobile", "work", "home", "other"], keyboard: .phonePad)
            TypedListSection(title: "Emails", items: $input.emails, placeholder: "name@example.com",
                             types: ["work", "home", "other"], keyboard: .emailAddress)
            TypedListSection(title: "Websites", items: $input.urls, placeholder: "https://…",
                             types: ["work", "home", "linkedin", "other"], keyboard: .URL)

            Section("Address") {
                ForEach($input.addresses) { $a in
                    VStack {
                        TextField("Street", text: $a.street)
                        HStack { TextField("City", text: $a.city); TextField("Region", text: $a.region) }
                        HStack { TextField("Postal", text: $a.postal); TextField("Country", text: $a.country) }
                    }
                }
                .onDelete { input.addresses.remove(atOffsets: $0) }
                Button { input.addresses.append(ContactAddress(type: "home")) } label: { Label("Add address", systemImage: "plus") }
            }

            Section("Circles") {
                TextField("Comma-separated, e.g. Friends, Work", text: $circlesText)
                if !knownCircles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(knownCircles, id: \.self) { circle in
                                Button(circle) { toggleCircle(circle) }
                                    .buttonStyle(.bordered)
                                    .tint(currentCircles.contains(circle) ? .accentColor : .secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            Section("Dates") {
                TextField("Birthday (YYYY-MM-DD or --MM-DD)", text: $input.birthday)
                TextField("Anniversary (YYYY-MM-DD)", text: $input.anniversary)
            }

            Section("About") {
                TextField("How we met", text: $input.howWeMet, axis: .vertical)
                TextField("Food preference", text: $input.foodPreference, axis: .vertical)
                TextField("Work information", text: $input.workInformation, axis: .vertical)
                TextField("Other contact information", text: $input.contactInformation, axis: .vertical)
            }

            Section("Custom fields") {
                ForEach($customFields) { $f in
                    HStack {
                        TextField("Key", text: $f.key).frame(maxWidth: 130)
                        Divider()
                        TextField("Value", text: $f.value)
                    }
                }
                .onDelete { customFields.remove(atOffsets: $0) }
                Button { customFields.append(KeyValue(key: "", value: "")) } label: { Label("Add field", systemImage: "plus") }
            }
        }
        .navigationTitle(isNew ? "New contact" : "Edit contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Create" : "Save") { Task { await save() } }
                    .disabled(saving || input.firstname.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .interactiveDismissDisabled(saving)
        .task {
            if case .edit(let c) = mode {
                input = c.input
                circlesText = c.circleList.joined(separator: ", ")
                customFields = c.customFieldList.map { KeyValue(key: $0.key, value: $0.value) }
            }
            knownCircles = (try? await APIClient.shared.circles()) ?? []
        }
    }

    private var currentCircles: [String] {
        circlesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func toggleCircle(_ circle: String) {
        var set = currentCircles
        if let i = set.firstIndex(of: circle) { set.remove(at: i) } else { set.append(circle) }
        circlesText = set.joined(separator: ", ")
    }

    private func save() async {
        saving = true
        error = nil
        var payload = input
        payload.firstname = payload.firstname.trimmingCharacters(in: .whitespaces)
        payload.circles = Array(NSOrderedSet(array: currentCircles)) as? [String] ?? currentCircles
        payload.phones = payload.phones.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        payload.emails = payload.emails.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        payload.urls = payload.urls.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        payload.addresses = payload.addresses.filter { !$0.formatted.isEmpty }
        payload.customFields = Dictionary(uniqueKeysWithValues: customFields
            .map { ($0.key.trimmingCharacters(in: .whitespaces), $0.value) }
            .filter { !$0.0.isEmpty })
        // Keep the legacy scalar fields in step with the first typed value (server does too).
        payload.phone = payload.phones.first?.value ?? ""
        payload.email = payload.emails.first?.value ?? ""
        payload.address = payload.addresses.first?.formatted ?? ""
        do {
            switch mode {
            case .create: _ = try await APIClient.shared.createContact(payload)
            case .edit(let c): _ = try await APIClient.shared.updateContact(c.id, payload)
            }
            state.contactsChanged()
            dismiss()
        } catch {
            self.error = describe(error)
        }
        saving = false
    }
}

/// Editable list of `{type, value}` pairs (phones, emails, URLs).
struct TypedListSection: View {
    var title: String
    @Binding var items: [TypedValue]
    var placeholder: String
    var types: [String]
    var keyboard: UIKeyboardType = .default

    var body: some View {
        Section(title) {
            ForEach(items.indices, id: \.self) { i in
                HStack {
                    Picker("", selection: $items[i].type) {
                        ForEach(types, id: \.self) { Text($0.capitalized).tag($0) }
                        if !types.contains(items[i].type) { Text(items[i].type.capitalized).tag(items[i].type) }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    TextField(placeholder, text: $items[i].value)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .onDelete { items.remove(atOffsets: $0) }
            Button { items.append(TypedValue(type: types.first ?? "", value: "")) } label: {
                Label("Add \(title.lowercased().dropLast())", systemImage: "plus")
            }
        }
    }
}
