import Foundation

struct ContactListItemDTO: Codable, Identifiable, Hashable {
    var id: String { contact_id }
    let contact_id: String
    let display_name: String
    let last_message_ts: String?
    let last_message_snippet: String?
    let total_messages: Int
}

struct MessageDTO: Codable, Identifiable, Hashable {
    var id: String { ts + direction + String(text.hashValue) }
    let ts: String
    let direction: String
    let text: String
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
