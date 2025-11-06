import SwiftUI

struct PeopleView: View {
    @State private var contacts: [ContactListItemDTO] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("👥 People").font(.largeTitle.bold())
                    Spacer()
                    Button {
                        Task { await load() }
                    } label: { Image(systemName: "arrow.clockwise") }
                }

                TextField("Search contacts…", text: $search)
                    .textFieldStyle(.roundedBorder)

                if isLoading { ProgressView("Loading…").padding(.vertical, 4) }
                if let error { Text(error).foregroundColor(.red) }

                List(filtered) { c in
                    NavigationLink {
                        PersonDetailView(contact: c)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(c.display_name).font(.headline)
                            HStack {
                                if let snip = c.last_message_snippet {
                                    Text(snip).lineLimit(1).foregroundColor(.secondary)
                                }
                                Spacer()
                                if let ts = c.last_message_ts {
                                    Text(short(ts)).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)

                Spacer()
            }
            .padding()
            .onAppear { Task { await load() } }
        }
    }

    private var filtered: [ContactListItemDTO] {
        guard !search.isEmpty else { return contacts }
        return contacts.filter { $0.display_name.localizedCaseInsensitiveContains(search) ||
                                 $0.contact_id.localizedCaseInsensitiveContains(search) }
    }

    private func load() async {
        isLoading = true; defer { isLoading = false }
        do { contacts = try await APIClient.fetchContacts() }
        catch { self.error = "Failed to load contacts: \(error.localizedDescription)" }
    }

    private func short(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateStyle = .short; out.timeStyle = .short
        return out.string(from: d)
    }
}
