import SwiftUI

struct HomeView: View {
    @State private var unreadMessages: [UnreadMessageDTO] = []
    @State private var unreadCount: Int = 0
    @State private var isLoading = false
    @State private var error: String?
    @State private var timer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("🏠 Home")
                        .font(.largeTitle.bold())
                    Spacer()
                    if unreadCount > 0 {
                        Text("\(unreadCount) unread")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                    Button {
                        Task { await loadUnreadMessages() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
                
                if isLoading && unreadMessages.isEmpty {
                    ProgressView("Loading unread messages...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
                if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                if unreadMessages.isEmpty && !isLoading {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Unread Messages")
                            .font(.headline)
                        Text("You're all caught up! No new messages from contacts.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                
                // Unread Messages Notifications
                ForEach(unreadMessages) { message in
                    UnreadMessageCard(
                        message: message,
                        onMarkRead: {
                            Task {
                                await markAsRead(message: message)
                            }
                        }
                    )
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            Task {
                await loadUnreadMessages()
            }
            // Poll for new messages every 5 seconds
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    private func loadUnreadMessages() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            unreadMessages = try await APIClient.fetchUnreadMessages()
            unreadCount = unreadMessages.count
        } catch {
            self.error = error.localizedDescription
            print("Failed to load unread messages: \(error)")
        }
    }
    
    private func markAsRead(message: UnreadMessageDTO) async {
        do {
            try await APIClient.markAsRead(contactID: message.contact_id, messageID: message.message_id)
            // Reload unread messages
            await loadUnreadMessages()
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await loadUnreadMessages()
            }
        }
    }
    
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}

struct UnreadMessageCard: View {
    let message: UnreadMessageDTO
    let onMarkRead: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.display_name)
                        .font(.headline)
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    onMarkRead()
                } label: {
                    Text("Mark Read")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Text(message.message)
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: timestamp) else {
            return timestamp
        }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}
