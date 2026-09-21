import Foundation

// Mirrors backend/models/contact.go. Go's gorm.Model exposes `ID`, `CreatedAt`,
// `UpdatedAt`, `DeletedAt` with that exact casing; every other key is snake_case.
// Arrays come back as `null` when empty, so they are decoded as optionals and
// exposed with non-optional accessors.

struct TypedValue: Codable, Hashable, Identifiable {
    var type: String
    var value: String
    var id: String { type + "|" + value }
}

struct ContactAddress: Codable, Hashable, Identifiable {
    var type: String = ""
    var street: String = ""
    var city: String = ""
    var region: String = ""
    var postal: String = ""
    var country: String = ""

    var id: String { [type, street, city, region, postal, country].joined(separator: "|") }
    var formatted: String {
        [street, city, region, postal, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct Contact: Codable, Identifiable, Hashable {
    var id: Int
    var createdAt: Date?
    var updatedAt: Date?

    var firstname: String
    var lastname: String = ""
    var nickname: String = ""
    var gender: String = ""
    var email: String = ""
    var phone: String = ""
    var birthday: String = ""
    var photo: String = ""
    var photoThumbnail: String?
    var address: String = ""
    var howWeMet: String = ""
    var foodPreference: String = ""
    var workInformation: String = ""
    var contactInformation: String = ""
    var circles: [String]?
    var emails: [TypedValue]?
    var phones: [TypedValue]?
    var addresses: [ContactAddress]?
    var urls: [TypedValue]?
    var impps: [TypedValue]?
    var prefix: String = ""
    var middleName: String = ""
    var suffix: String = ""
    var organization: String = ""
    var department: String = ""
    var jobTitle: String = ""
    var role: String = ""
    var anniversary: String = ""
    var customFields: [String: String]?
    var archived: Bool = false

    // Present only when fetched with `?includes=...`.
    var notes: [Note]?
    var activities: [Activity]?
    var reminders: [Reminder]?
    var relationships: [Relationship]?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case createdAt = "CreatedAt"
        case updatedAt = "UpdatedAt"
        case firstname, lastname, nickname, gender, email, phone, birthday, photo
        case photoThumbnail = "photo_thumbnail"
        case address
        case howWeMet = "how_we_met"
        case foodPreference = "food_preference"
        case workInformation = "work_information"
        case contactInformation = "contact_information"
        case circles, emails, phones, addresses, urls, impps, prefix
        case middleName = "middle_name"
        case suffix, organization, department
        case jobTitle = "job_title"
        case role, anniversary
        case customFields = "custom_fields"
        case archived, notes, activities, reminders, relationships
    }

    var fullName: String {
        let name = [firstname, lastname].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "(no name)" : name
    }

    var initials: String {
        let f = firstname.first.map(String.init) ?? ""
        let l = lastname.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    /// Job title + organization as one line, e.g. "CTO · Cyera".
    var subtitle: String {
        [jobTitle, organization].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var circleList: [String] { circles ?? [] }
    var emailList: [TypedValue] { emails ?? [] }
    var phoneList: [TypedValue] { phones ?? [] }
    var addressList: [ContactAddress] { addresses ?? [] }
    var urlList: [TypedValue] { urls ?? [] }
    var imppList: [TypedValue] { impps ?? [] }
    var customFieldList: [(key: String, value: String)] {
        (customFields ?? [:]).sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }
    }

    /// Thumbnail is stored server-side as a `data:image/jpeg;base64,...` URL.
    var thumbnailData: Data? {
        guard let t = photoThumbnail, let comma = t.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(t[t.index(after: comma)...]))
    }

    /// Everything the server accepts on POST/PUT (backend/models/dtos.go ContactInput).
    /// PUT is a full replace, so this always carries every field.
    var input: ContactInput {
        ContactInput(
            firstname: firstname, lastname: lastname, nickname: nickname, gender: gender,
            email: email, phone: phone, birthday: birthday, address: address,
            howWeMet: howWeMet, foodPreference: foodPreference,
            workInformation: workInformation, contactInformation: contactInformation,
            circles: circleList, customFields: customFields ?? [:],
            emails: emailList, phones: phoneList, addresses: addressList,
            urls: urlList, impps: imppList,
            prefix: prefix, middleName: middleName, suffix: suffix,
            organization: organization, department: department, jobTitle: jobTitle,
            role: role, anniversary: anniversary
        )
    }
}

struct ContactInput: Codable, Hashable {
    var firstname: String = ""
    var lastname: String = ""
    var nickname: String = ""
    var gender: String = ""
    var email: String = ""
    var phone: String = ""
    var birthday: String = ""
    var address: String = ""
    var howWeMet: String = ""
    var foodPreference: String = ""
    var workInformation: String = ""
    var contactInformation: String = ""
    var circles: [String] = []
    var customFields: [String: String] = [:]
    var emails: [TypedValue] = []
    var phones: [TypedValue] = []
    var addresses: [ContactAddress] = []
    var urls: [TypedValue] = []
    var impps: [TypedValue] = []
    var prefix: String = ""
    var middleName: String = ""
    var suffix: String = ""
    var organization: String = ""
    var department: String = ""
    var jobTitle: String = ""
    var role: String = ""
    var anniversary: String = ""

    enum CodingKeys: String, CodingKey {
        case firstname, lastname, nickname, gender, email, phone, birthday, address
        case howWeMet = "how_we_met"
        case foodPreference = "food_preference"
        case workInformation = "work_information"
        case contactInformation = "contact_information"
        case circles
        case customFields = "custom_fields"
        case emails, phones, addresses, urls, impps, prefix
        case middleName = "middle_name"
        case suffix, organization, department
        case jobTitle = "job_title"
        case role, anniversary
    }
}

struct ContactPage: Codable {
    var contacts: [Contact]?
    var total: Int
    var page: Int
    var limit: Int
    var items: [Contact] { contacts ?? [] }
}

struct Birthday: Codable, Identifiable {
    var id: Int
    var firstname: String
    var lastname: String
    var birthday: String
    var photoThumbnail: String?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case firstname, lastname, birthday
        case photoThumbnail = "photo_thumbnail"
    }
    var fullName: String { [firstname, lastname].filter { !$0.isEmpty }.joined(separator: " ") }
}

struct User: Codable {
    var id: Int
    var username: String
    var email: String
    var isAdmin: Bool?
    var customFieldNames: [String]?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case isAdmin = "is_admin"
        case customFieldNames = "custom_field_names"
    }
}
