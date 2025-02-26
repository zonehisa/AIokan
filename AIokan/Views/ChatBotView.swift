import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

struct ChatBotView: View {
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                HStack(spacing: 8) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    
                    TextField("メッセージを入力", text: $newMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(newMessage.isEmpty)
                }
                .padding()
            }
            .navigationTitle("AIオカン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // タスク提案
                    }) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        let message = Message(content: newMessage, isFromUser: true, timestamp: Date())
        messages.append(message)
        newMessage = ""
        
        // AIオカンからの返信をシミュレート
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = Message(content: "了解しました！頑張ってね！", isFromUser: false, timestamp: Date())
            messages.append(response)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading) {
                Text(message.content)
                    .padding(10)
                    .background(message.isFromUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(15)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
}

#Preview {
    ChatBotView()
} 
