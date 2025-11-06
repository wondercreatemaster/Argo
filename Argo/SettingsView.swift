import SwiftUI

struct SettingsView: View {
    @State private var localOnly = true
    @State private var learningEnabled = true

    var body: some View {
        Form {
            Section(header: Text("Learning Mode")) {
                Toggle("Enable Learning", isOn: $learningEnabled)
                Text("When enabled, Argo learns your writing tone and summaries.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Privacy")) {
                Toggle("Local-Only Data", isOn: $localOnly)
                Text("When ON, all data stays on this Mac.").font(.footnote)
            }

            Section(header: Text("About")) {
                Text("Argo v1.0.0")
                Text("© 2025 – Inbox Copilot AI")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: 600)
    }
}
