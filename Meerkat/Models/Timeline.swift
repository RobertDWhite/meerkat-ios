import Foundation

// Notes, activities, reminders and relationships — the "timeline" attached to a contact.
// See backend/models/{note,activity,reminder,relationship}.go.

struct Note: Codable, Identifiable, Hashable {
    var id: Int
    var content: String
    var date: Date
    var contactId: Int?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case content, date
        case contactId = "contact_id"
    }
}

struct NoteInput: Codable {
    var content: String
    var date: Date
    var contactId: Int?
    enum CodingKeys: String, CodingKey {
        case content, date
        case contactId = "contact_id"
    }
}

struct Activity: Codable, Identifiable, Hashable {
    var id: Int
    var title: String
    var description: String = ""
    var location: String = ""
    var date: Date
    var contacts: [Contact]?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case title, description, location, date, contacts
    }
}

struct ActivityInput: Codable {
    var title: String
    var description: String = ""
    var location: String = ""
    var date: Date
    var contactIds: [Int]
    enum CodingKeys: String, CodingKey {
        case title, description, location, date
        case contactIds = "contact_ids"
    }
}

enum Recurrence: String, CaseIterable, Codable, Identifiable {
    case once, weekly, monthly, quarterly
    case sixMonths = "six-months"
    case yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .once: return "Once"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .sixMonths: return "Every 6 months"
        case .yearly: return "Yearly"
        }
    }
}

struct Reminder: Codable, Identifiable, Hashable {
    var id: Int
    var message: String
    var byMail: Bool?
    var remindAt: Date
    var recurrence: String
    var reoccurFromCompletion: Bool?
    var completed: Bool = false
    var contactId: Int?
    var contact: Contact?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case message
        case byMail = "by_mail"
        case remindAt = "remind_at"
        case recurrence
        case reoccurFromCompletion = "reoccur_from_completion"
        case completed
        case contactId = "contact_id"
        case contact
    }
}

struct ReminderInput: Codable {
    var message: String
    var byMail: Bool = false
    var remindAt: Date
    var recurrence: String
    var reoccurFromCompletion: Bool = true
    var contactId: Int
    enum CodingKeys: String, CodingKey {
        case message
        case byMail = "by_mail"
        case remindAt = "remind_at"
        case recurrence
        case reoccurFromCompletion = "reoccur_from_completion"
        case contactId = "contact_id"
    }
}

struct Relationship: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var type: String
    var gender: String = ""
    var birthday: String = ""
    var contactId: Int
    var relatedContactId: Int?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name, type, gender, birthday
        case contactId = "contact_id"
        case relatedContactId = "related_contact_id"
    }
}

struct RelationshipInput: Codable {
    var name: String
    var type: String
    var gender: String = ""
    var birthday: String = ""
    var relatedContactId: Int?
    enum CodingKeys: String, CodingKey {
        case name, type, gender, birthday
        case relatedContactId = "related_contact_id"
    }
}

// Envelopes used by the list endpoints.
struct NotesEnvelope: Codable { var notes: [Note]? }
struct ActivitiesEnvelope: Codable { var activities: [Activity]? }
struct RemindersEnvelope: Codable { var reminders: [Reminder]? }
struct RelationshipsEnvelope: Codable { var relationships: [Relationship]? }
struct BirthdaysEnvelope: Codable { var birthdays: [Birthday]? }
struct ContactEnvelope: Codable { var contact: Contact }
