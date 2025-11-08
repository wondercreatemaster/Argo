import Foundation

enum APIConfig {
    static let baseURL = URL(string: "http://127.0.0.1:8000")! // backend port
}

struct CreateDiscussionRequest: Codable {
    let title: String
    let tags: [String]
}

struct SSEChunk: Codable {
    let chunk: String?
    let full_text: String?
    let done: Bool?
    let error: String?
}

private struct CreateDiscussionResponse: Codable { let id: String }

enum APIClient {
    static func fetchContacts() async throws -> [ContactListItemDTO] {
        let url = APIConfig.baseURL.appendingPathComponent("/contacts")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([ContactListItemDTO].self, from: data)
    }

    static func fetchContactDetail(_ id: String) async throws -> ContactDTO {
        let url = APIConfig.baseURL.appendingPathComponent("/contacts/\(id)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ContactDTO.self, from: data)
    }

    static func analyzeContact(_ id: String, maxMessages: Int = 80) async throws -> AnalysisResultDTO {
        var req = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/contacts/\(id)/analyze"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AnalysisRequestDTO(max_messages: maxMessages))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(AnalysisResultDTO.self, from: data)
    }
    
    // MARK: - Discussions API

    static func fetchDiscussions() async throws -> [Discussion] {
        let url = APIConfig.baseURL.appendingPathComponent("/discussions")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([Discussion].self, from: data)
    }

    static func fetchDiscussionMessages(_ discussionID: String) async throws -> [ChatMessage] {
        let url = APIConfig.baseURL.appendingPathComponent("/discussions/\(discussionID)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        // backend returns a detail object, not a raw array
        let detail = try JSONDecoder().decode(DiscussionDetail.self, from: data)
        return detail.messages
    }

    static func createDiscussion(title: String, tags: [String]) async throws -> Discussion {
        var req = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/discussions/start"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(CreateDiscussionRequest(title: title, tags: tags))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        // server sends only { "id": ... } → construct Discussion on the client
        let created = try JSONDecoder().decode(CreateDiscussionResponse.self, from: data)
        return Discussion(id: created.id, title: title, tags: tags)
    }

    static func sendDiscussionMessage(_ discussionID: String, message: String) async throws -> ChatResponse {
        var req = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/discussions/\(discussionID)/chat"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["message": message])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
    
    static func streamDiscussionMessage(
            _ discussionID: String,
            message: String,
            onChunk: @escaping (String) -> Void
        ) async throws {
            guard let url = URL(string: "/discussions/\(discussionID)/chat", relativeTo: APIConfig.baseURL) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["message": message])

            let (stream, response) = try await URLSession.shared.bytes(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            for try await line in stream.lines {
                guard line.hasPrefix("data:") else { continue }
                let trimmed = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard let data = trimmed.data(using: .utf8) else { continue }

                if let chunkObj = try? JSONDecoder().decode(SSEChunk.self, from: data) {
                    if let error = chunkObj.error {
                        throw NSError(domain: "SSEError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
                    }
                    if chunkObj.done == true { break }
                    if let chunk = chunkObj.chunk {
                        await MainActor.run {
                            onChunk(chunk)
                        }
                    }
                }
            }
        }
    
    
    static func deleteDiscussion(_ discussionID: String) async throws {
        var req = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/discussions/\(discussionID)"))
        req.httpMethod = "DELETE"
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

}
