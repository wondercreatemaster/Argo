import SwiftUI

struct DiscussionsView: View {
    @State private var discussions: [Discussion] = []
    @State private var selectedID: String?
    @State private var chatMessages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var showingNewDiscussionSheet = false

    var body: some View {
        HStack(spacing: 0) {

            // ===== LEFT: SIDEBAR =====
            VStack(spacing: 0) {
                HStack {
                    Text("💬 Discussions").font(.headline)
                    Spacer()
                    Button {
                        showingNewDiscussionSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill").imageScale(.large)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                List(selection: $selectedID) {
                    ForEach(discussions, id: \.id) { d in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.title).font(.body.bold())
                            if !d.tags.isEmpty {
                                Text(d.tags.joined(separator: ", "))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .tag(d.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedID = d.id
                            loadMessages(for: d.id)
                        }
                    }
                    .onDelete(perform: deleteDiscussion)
                }
            }
            .frame(maxWidth: 200, maxHeight: .infinity) // <- fixed
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ===== RIGHT: CHAT AREA =====
            VStack(spacing: 0) {
                if let id = selectedID, let topic = discussions.first(where: { $0.id == id }) {
                    HStack {
                        Text(topic.title).font(.title3.bold())
                        Spacer()
                        Button(role: .destructive) {
                            deleteCurrentDiscussion()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Delete this discussion")
                    }.padding(10)

                    Divider()

                    ScrollViewReader { sr in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(chatMessages) { msg in
                                    HStack {
                                        if msg.role == "user" {
                                            Spacer()
                                            Text(msg.text)
                                                .padding(10)
                                                .foregroundColor(.white)
                                                .background(Color.accentColor)
                                                .cornerRadius(10)
                                                .frame(maxWidth: 500, alignment: .trailing)
                                        } else {
                                            Text(msg.text)
                                                .padding(10)
                                                .background(Color(nsColor: .controlBackgroundColor))
                                                .cornerRadius(10)
                                                .frame(maxWidth: 500, alignment: .leading)
                                            Spacer()
                                        }
                                    }
                                    .id(msg.id)
                                    .padding(.horizontal, 8)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onChange(of: chatMessages.count) { _, _ in
                            if let last = chatMessages.last?.id {
                                withAnimation { sr.scrollTo(last, anchor: .bottom) }
                            }
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        TextField("Type a message…", text: $newMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                if let id = selectedID { sendMessageStreaming(for: id) }
                            }
                        Button {
                            if let id = selectedID { sendMessageStreaming(for: id) }
                        } label: { Image(systemName: "paperplane.fill") }
                        .buttonStyle(.bordered)
                    }
                    .padding(10)

                } else {
                    Spacer()
                    Text("Select or start a discussion.").foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: 700, minHeight: 520)
        .onAppear { loadDiscussions() }
        .onChange(of: selectedID) { _, newID in
            if let id = newID {
                loadMessages(for: id)
            }
        }
        .sheet(isPresented: $showingNewDiscussionSheet) {
            NewDiscussionSheet(isPresented: $showingNewDiscussionSheet) { title, tags in
                createDiscussion(title: title, tags: tags)
            }
        }
    }

    // MARK: - API
    private func loadDiscussions() {
        Task {
            do {
                let list = try await APIClient.fetchDiscussions()
                await MainActor.run {
                    discussions = list
                    if selectedID == nil { selectedID = list.first?.id }
                }
                if let id = selectedID { loadMessages(for: id) }
            } catch { print("Failed to load discussions:", error) }
        }
    }

    private func loadMessages(for id: String) {
        Task {
            do {
                let msgs = try await APIClient.fetchDiscussionMessages(id)
                await MainActor.run { chatMessages = msgs }
            } catch {
                await MainActor.run { chatMessages = [.init(role: "system", text: "⚠️ \(error.localizedDescription)")] }
            }
        }
    }
    
    private func sendMessageStreaming(for id: String) {
        let text = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newMessage = ""

        // Immediately show the user message
        chatMessages.append(ChatMessage(role: "user", text: text))

        Task { @MainActor in
            var assistantIndex: Int? = nil

            do {
                try await APIClient.streamDiscussionMessage(id, message: text) { chunk in
                    // This closure runs off-main; re-enter MainActor for UI updates
                    Task { @MainActor in
                        if let idx = assistantIndex {
                            chatMessages[idx].text += chunk
                        } else {
                            let msg = ChatMessage(role: "assistant", text: chunk)
                            chatMessages.append(msg)
                            assistantIndex = chatMessages.count - 1
                        }
                    }
                }
            } catch {
                chatMessages.append(ChatMessage(role: "system",
                                                text: "❌ \(error.localizedDescription)"))
            }
        }
    }




    private func sendMessage(for id: String) {
        let text = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newMessage = ""
        chatMessages.append(.init(role: "user", text: text))
        Task {
            do {
                let reply = try await APIClient.sendDiscussionMessage(id, message: text)
                await MainActor.run { chatMessages.append(.init(role: "assistant", text: reply.reply)) }
            } catch {
                await MainActor.run { chatMessages.append(.init(role: "system", text: "❌ \(error.localizedDescription)")) }
            }
        }
    }

    private func createDiscussion(title: String, tags: [String]) {
        Task {
            do {
                let new = try await APIClient.createDiscussion(title: title, tags: tags)
                await MainActor.run {
                    discussions.append(new)
                    selectedID = new.id
                    chatMessages = []
                }
            } catch { print("Create discussion failed:", error) }
        }
    }
    
    private func deleteDiscussion(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let id = discussions[index].id
                do {
                    try await APIClient.deleteDiscussion(id)
                    await MainActor.run {
                        discussions.remove(at: index)
                        if selectedID == id {
                            selectedID = discussions.first?.id
                            if let newID = selectedID {
                                loadMessages(for: newID)
                            } else {
                                chatMessages = []
                            }
                        }
                    }
                } catch {
                    print("❌ Delete failed: \(error)")
                }
            }
        }
    }
    
    private func deleteCurrentDiscussion() {
        guard let id = selectedID else { return }
        Task {
            do {
                try await APIClient.deleteDiscussion(id)
                await MainActor.run {
                    discussions.removeAll { $0.id == id }
                    selectedID = discussions.first?.id
                    chatMessages = []
                }
            } catch {
                print("Delete failed: \(error)")
            }
        }
    }


}


struct NewDiscussionSheet: View {
    @Binding var isPresented: Bool
    var onCreate: (String, [String]) -> Void

    @State private var title = ""
    @State private var tags = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🆕 New Discussion")
                .font(.title2.bold())

            TextField("Title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Tags (comma separated)", text: $tags)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Create") {
                    let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    onCreate(title, tagList)
                    isPresented = false
                }
                .disabled(title.isEmpty)
            }
            .padding(.top)

        }
        .padding(30)
        .frame(width: 400)
    }
}


struct Discussion: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let tags: [String]
}

struct DiscussionDetail: Codable {
    let title: String
    let tags: [String]
    let messages: [ChatMessage]
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let role: String
    var text: String

    enum CodingKeys: String, CodingKey {
        case role, text
    }

    init(role: String, text: String) {
        self.role = role
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        id = UUID()  // always generate a new one
    }
}


struct ChatResponse: Codable {
    let reply: String
}

struct DiscussionChatView: View {
    let discussion: Discussion
    @Binding var chatMessages: [ChatMessage]
    @Binding var newMessage: String
    var onSend: (String) -> Void

    var body: some View {
        VStack {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chatMessages) { msg in
                            HStack {
                                if msg.role == "user" {
                                    Spacer()
                                    Text(msg.text)
                                        .padding(10)
                                        .foregroundColor(.white)
                                        .background(Color.accentColor)
                                        .cornerRadius(10)
                                        .frame(maxWidth: 400, alignment: .trailing)
                                } else {
                                    Text(msg.text)
                                        .padding(10)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(10)
                                        .frame(maxWidth: 400, alignment: .leading)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: chatMessages.count) { _, _ in
                    if let last = chatMessages.last?.id {
                        withAnimation {
                            scrollView.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack {
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit { onSend(newMessage) }

                Button {
                    onSend(newMessage)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
    }
}

