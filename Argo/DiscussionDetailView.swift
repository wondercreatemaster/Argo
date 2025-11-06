import SwiftUI

struct DiscussionDetailView: View {
    let discussion: Discussion
    @Binding var chatMessages: [ChatMessage]
    @Binding var newMessage: String
    var sendMessage: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { scrollView in
                ScrollView {
                    ForEach(chatMessages, id: \.id) { msg in
                        HStack {
                            if msg.role == "user" {
                                Spacer()
                                Text(msg.text)
                                    .padding(10)
                                    .background(Color.blue.opacity(0.7))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 400, alignment: .trailing)
                            } else {
                                Text(msg.text)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                    .frame(maxWidth: 400, alignment: .leading)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .onChange(of: chatMessages.count) { oldValue, newValue in
                    if newValue > oldValue, let last = chatMessages.last?.id {
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
                    .onSubmit { sendMessage(newMessage) }

                Button {
                    sendMessage(newMessage)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
        .navigationTitle(discussion.title)
    }
}
