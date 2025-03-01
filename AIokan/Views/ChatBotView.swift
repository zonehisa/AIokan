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

    // 画像関連
    @State private var showAlert = false
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationView {
            VStack {
                // ---- メッセージ一覧表示 ----
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
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

        // 3. 画像がある場合はアップロードしてからワークフロー呼び出し
        if let image = imageToSend {
            DifyAPI.uploadImage(image: image) { result in
                switch result {
                case .success(let json):
                    // アップロード成功 → json には {"id":..., "name":..., ...} などが入っている想定
                    if let fileId = json["id"] as? String {
                        // アップロードしたファイルIDを使ってワークフロー実行
                        runDifyWorkflow(fileId: fileId, text: textToSend)
                    } else {
                        print("ファイルIDが見つかりません")
                    }
                case .failure(let error):
                    print("画像アップロード失敗: \(error.localizedDescription)")
                }
            }
        } else {
            // 画像がない場合はテキストだけワークフローに送る
            runDifyWorkflow(fileId: nil, text: textToSend)
        }
    }

    // 画像の有無にかかわらずワークフローを呼ぶ共通処理
    private func runDifyWorkflow(fileId: String?, text: String) {
        DifyAPI.runWorkflow(fileId: fileId, text: text) { result in
            switch result {
            case .success(let reply):
                DispatchQueue.main.async {
                    let responseMessage = Message(content: reply, isFromUser: false, timestamp: Date())
                    messages.append(responseMessage)
                }
            case .failure(let error):
                print("ワークフロー実行エラー: \(error.localizedDescription)")
            }
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
