import Foundation

struct ContactListItemDTO: Codable, Identifiable, Hashable {
    var id: String { contact_id }
    let contact_id: String
    let display_name: String
    let last_message_ts: String?
    let last_message_snippet: String?
    let total_messages: Int?
}

struct MessageDTO: Codable, Identifiable, Hashable {
    var id: String { (timestamp ?? "") + role + String(text.hashValue) }
    let timestamp: String?
    let role: String
    let text: String
    let sender: String?
}

struct ContactDTO: Codable, Identifiable {
    var id: String { contact_id }
    let contact_id: String
    let display_name: String
    let messages: [MessageDTO]
}

struct AnalysisRequestDTO: Codable { let max_messages: Int }

struct AnalysisResultDTO: Codable {
    let contact_id: String
    let display_name: String
    let tone_summary: String
    let facts: [String]
    let history_summary: String
}

struct UnreadMessageDTO: Codable, Identifiable {
    var id: String { "\(contact_id)-\(message_id)" }
    let contact_id: String
    let display_name: String
    let message: String
    let timestamp: String
    let message_id: Int
}

struct UnreadCountResponse: Codable {
    let count: Int
}

struct MarkReadRequestDTO: Codable {
    let contact_id: String
    let message_id: Int
}
