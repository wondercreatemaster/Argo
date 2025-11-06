import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("🏠 Home")
                    .font(.largeTitle.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Context Summary")
                        .font(.headline)
                    Text("Here you’ll see what’s currently on screen and quick suggestions for how to reply or act.")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Suggestions")
                        .font(.headline)
                    ForEach(0..<3) { i in
                        Text("• Suggestion \(i+1): example response.")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
        }
    }
}
