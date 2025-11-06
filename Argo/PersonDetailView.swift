import SwiftUI

struct PersonDetailView: View {
    let contact: ContactListItemDTO
    @State private var detail: ContactDTO?
    @State private var analysis: AnalysisResultDTO?
    @State private var loadingDetail = false
    @State private var loadingAnalysis = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(contact.display_name).font(.largeTitle.bold())

                GroupBox("Profile") {
                    if let a = analysis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tone").font(.headline)
                            Text(a.tone_summary)

                            Divider()
                            Text("Facts").font(.headline)
                            if a.facts.isEmpty {
                                Text("No durable facts detected yet.").foregroundColor(.secondary)
                            } else {
                                ForEach(a.facts, id: \.self) { f in
                                    Label(f, systemImage: "lightbulb")
                                }
                            }

                            Divider()
                            Text("History Summary").font(.headline)
                            Text(a.history_summary)
                        }
                    } else {
                        Text("Click **Analyze** to generate tone, facts, and a summary.")
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Button {
                        Task { await analyze() }
                    } label: {
                        if loadingAnalysis { ProgressView() } else { Text("Analyze") }
                    }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(loadingAnalysis)

                    Button {
                        Task { await loadDetail() }
                    } label: {
                        if loadingDetail { ProgressView() } else { Text("Reload Messages") }
                    }
                    .disabled(loadingDetail)
                }

                GroupBox("Recent Messages (last 200)") {
                    if let d = detail {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(d.messages.suffix(200), id: \.id) { m in
                                MessageRow(message: m)
                            }
                        }
                    } else {
                        Text("Loading…").foregroundColor(.secondary)
                    }
                }

                if let error { Text(error).foregroundColor(.red) }
                Spacer()
            }
            .padding()
        }
        .navigationTitle(contact.display_name)
        .onAppear { Task { await loadDetail() } }
    }

    private func loadDetail() async {
        loadingDetail = true; defer { loadingDetail = false }
        do { detail = try await APIClient.fetchContactDetail(contact.contact_id) }
        catch { self.error = "Failed to load detail: \(error.localizedDescription)" }
    }

    private func analyze() async {
        loadingAnalysis = true; defer { loadingAnalysis = false }
        do { analysis = try await APIClient.analyzeContact(contact.contact_id, maxMessages: 80) }
        catch { self.error = "Failed to analyze: \(error.localizedDescription)" }
    }
}

struct MessageRow: View {
    let message: MessageDTO
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message.direction.uppercased())
                .font(.caption2).padding(.vertical, 2).padding(.horizontal, 6)
                .background(message.direction == "in" ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(message.text)
                Text(message.ts).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
    }
}
