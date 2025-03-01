import SwiftUI

struct Message: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

struct ChatBotView: View {
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""

    // 画像関連
    @State private var showAlert = false
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationView {
            VStack {
                // ---- メッセージ一覧表示 ----
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id) // 各メッセージにIDを設定
                            }
                        }
                        .padding()
                        .onChange(of: messages, perform: { _ in
                            // 最新のメッセージにスクロール
                            if let lastMessage = messages.last {
                                scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        })
                    }
                }

                // ---- 画像プレビューを左側に表示 ----
                if let previewImage = capturedImage {
                    HStack {
                        ZStack(alignment: .topTrailing) {
                            // プレビュー画像
                            Image(uiImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            // バツボタン
                            Button(action: {
                                capturedImage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                    .padding(2)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }

                // ---- 入力エリア ----
                HStack(spacing: 8) {
                    // 画像選択ボタン
                    Button(action: {
                        showAlert = true
                    }) {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .alert("画像の取得先を選択", isPresented: $showAlert) {
                        Button("カメラ") {
                            sourceType = .camera
                            showImagePicker = true
                        }
                        Button("フォトライブラリ") {
                            sourceType = .photoLibrary
                            showImagePicker = true
                        }
                        Button("キャンセル", role: .cancel) {}
                    }
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(image: $capturedImage, sourceType: sourceType)
                    }

                    // テキスト入力欄
                    TextField("メッセージを入力", text: $newMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    // 送信ボタン
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                    }
                    // テキストも画像もないときは無効化
                    .disabled(newMessage.isEmpty && capturedImage == nil)
                }
                .padding()
            }
            .navigationTitle("AIオカン")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // ---- 送信処理 ----
    private func sendMessage() {
        // 1. ユーザーの入力を即座に画面に表示
        let userMessage = Message(content: newMessage, isFromUser: true, timestamp: Date())
        messages.append(userMessage)

        // 2. データ退避
        let textToSend = newMessage
        let imageToSend = capturedImage

        // リセット
        newMessage = ""
        capturedImage = nil

        // 3. 画像がある場合は処理
        if let image = imageToSend {
            // 画像を送信する処理をここに追加
            uploadImage(image) { result in
                switch result {
                case .success(let imageUrl):
                    // 画像のURLをメッセージとして送信
                    let imageMessage = Message(content: imageUrl, isFromUser: false, timestamp: Date())
                    messages.append(imageMessage)

                    // Gemini APIを呼び出す
                    callGeminiAPI(with: imageUrl) { response in
                        // Gemini APIのレスポンスを処理
                        let geminiMessage = Message(content: response, isFromUser: false, timestamp: Date())
                        messages.append(geminiMessage)
                    }
                case .failure(let error):
                    print("画像送信エラー: \(error.localizedDescription)")
                    // エラーメッセージを表示
                    let errorMessage = Message(content: "画像の送信中にエラーが発生しました。", isFromUser: false, timestamp: Date())
                    messages.append(errorMessage)
                }
            }
        } else {
            // 画像がない場合はテキストのみで処理
            // Gemini APIを呼び出す処理をここに追加
            callGeminiAPI(with: textToSend) { response in
                let geminiMessage = Message(content: response, isFromUser: false, timestamp: Date())
                messages.append(geminiMessage)
            }
        }

        // キーボードを閉じる
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // 画像をアップロードする関数の例
    private func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // ここに画像をアップロードする処理を実装
        // 成功した場合は画像のURLを返す
        // 失敗した場合はエラーを返す
    }

    // Gemini APIを呼び出す関数
    private func callGeminiAPI(with input: String, completion: @escaping (String) -> Void) {
        // API呼び出しの実装
        // ここでGemini APIにリクエストを送信し、レスポンスを受け取る処理を実装します
        // 成功した場合はcompletionにレスポンスを渡す
        // 失敗した場合はエラーハンドリングを行う
    }

    // 古いDify用メソッド（互換性のために残していますが使用しないでください）
    private func runDifyWorkflow(fileId: String?, text: String) {
        print("警告: 古いrunDifyWorkflowメソッドが呼び出されました。代わりにGemini APIを使用してください。")
        // 「互換性のないAPIです」というメッセージを表示
        DispatchQueue.main.async {
            let errorMessage = Message(content: "申し訳ありませんが、このAPIは現在利用できません。", isFromUser: false, timestamp: Date())
            messages.append(errorMessage)
        }
    }

}
struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            } else {
                // ロゴのイメージを表示
                Image("logo") // ロゴの画像名を指定
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50) // サイズを調整
                    .clipShape(Circle())
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
