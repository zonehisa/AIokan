import SwiftUI

struct Message: Identifiable, Equatable {
    let id = UUID()
    let content: String? // テキスト（オプションに変更）
    let image: UIImage? // 画像を追加
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
                                .frame(width: 100, height: 100)
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
            .onAppear {
                // 初回表示時に会話履歴をリセット
                DifyAPI.resetConversation()
                
                // 初回メッセージがない場合は追加
                if messages.isEmpty {
                    // 初期メッセージを追加（オプション）
                    let initialMessage = Message(
                        content: "こんにちは！AIオカンやで〜。なんか困ってることあらへん？なんでも聞いてや！",
                        image: nil,
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(initialMessage)
                }
            }
        }
    }
    
    // ---- 送信処理 ----
    private func sendMessage() {
        if newMessage.isEmpty && capturedImage == nil {
            return
        }
        
        // ユーザーメッセージを作成（テキストと画像両方対応）
        let userMessage = Message(
            content: newMessage.isEmpty ? nil : newMessage,
            image: capturedImage,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // 「考え中...」を表示
        let processingMessage = Message(content: "考え中...", image: nil, isFromUser: false, timestamp: Date())
        messages.append(processingMessage)
        
        let textToSend = newMessage
        let imageToSend = capturedImage
        
        newMessage = ""
        capturedImage = nil
        
        if let image = imageToSend {
            uploadImage(image) { result in
                switch result {
                case .success(let imageUrl):
                    let promptText = textToSend.isEmpty ? nil : textToSend
                    DifyAPI.generateFromImageAndText(prompt: promptText, image: image) { result in
                        DispatchQueue.main.async {
                            // 「考え中...」を削除
                            if let lastMessage = self.messages.last, lastMessage.content == "考え中..." {
                                self.messages.removeLast()
                            }
                            
                            switch result {
                            case .success(let response):
                                let geminiMessage = Message(content: response, image: nil, isFromUser: false, timestamp: Date())
                                self.messages.append(geminiMessage)
                            case .failure(let error):
                                let errorMessage = Message(content: "エラーやで: \(error.localizedDescription)", image: nil, isFromUser: false, timestamp: Date())
                                self.messages.append(errorMessage)
                            }
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        // 「考え中...」を削除
                        if let lastMessage = self.messages.last, lastMessage.content == "考え中..." {
                            self.messages.removeLast()
                        }
                        
                        let errorMessage = Message(content: "画像送るの失敗したわ: \(error.localizedDescription)", image: nil, isFromUser: false, timestamp: Date())
                        self.messages.append(errorMessage)
                    }
                }
            }
        } else {
            DifyAPI.generateText(prompt: textToSend) { result in
                DispatchQueue.main.async {
                    // 「考え中...」を削除
                    if let lastMessage = self.messages.last, lastMessage.content == "考え中..." {
                        self.messages.removeLast()
                    }
                    
                    switch result {
                    case .success(let response):
                        let geminiMessage = Message(content: response, image: nil, isFromUser: false, timestamp: Date())
                        self.messages.append(geminiMessage)
                    case .failure(let error):
                        let errorMessage = Message(content: "エラーやで: \(error.localizedDescription)", image: nil, isFromUser: false, timestamp: Date())
                        self.messages.append(errorMessage)
                    }
                }
            }
        }
        
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // 画像をアップロードする関数の例
    private func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // このアプリでは実際のサーバーアップロードは行わず、ローカルURLを使用します
        guard let compressedImageData = image.jpegData(compressionQuality: 0.5) else {
            completion(.failure(NSError(domain: "画像圧縮エラー", code: -1)))
            return
        }
        
        // 一時ディレクトリにファイルを保存
        let fileName = "temp_image_\(UUID().uuidString).jpg"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try compressedImageData.write(to: fileURL)
            completion(.success(fileURL.absoluteString))
        } catch {
            print("画像保存エラー: \(error)")
            completion(.failure(error))
        }
    }
    
    // Gemini APIを呼び出す関数
    private func callGeminiAPI(with input: String, completion: @escaping (String) -> Void) {
        // メッセージを表示して処理中であることを示す
        DispatchQueue.main.async {
            let processingMessage = Message(content: "考え中...", image: nil, isFromUser: false, timestamp: Date())
            messages.append(processingMessage)
        }
        
        // 入力がURLの形式かどうかを判断（画像処理の場合）
        if input.hasPrefix("http") {
            // 仮実装: 画像の説明を要求するプロンプト
            let prompt = ""
            
            // 画像URLから画像を取得
            if let url = URL(string: input), let image = loadImageFromURL(url) {
                // Gemini Vision APIを呼び出し
                DifyAPI.generateFromImageAndText(prompt: prompt, image: image) { result in
                    DispatchQueue.main.async {
                        // 「考え中...」メッセージを削除
                        if let lastMessage = self.messages.last, lastMessage.content == "考え中..." {
                            self.messages.removeLast()
                        }
                        
                        switch result {
                        case .success(let response):
                            completion(response)
                        case .failure(let error):
                            completion("申し訳ありません、エラーが発生しました: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    // 「考え中...」メッセージを削除
                    if let lastMessage = self.messages.last, lastMessage.content == "考え中..." {
                        self.messages.removeLast()
                    }
                    completion("画像の読み込みに失敗しました。")
                }
            }
        } else {
            // テキストのみの場合
            DifyAPI.generateText(prompt: input) { result in
                DispatchQueue.main.async {
                    // 「考え中...」メッセージを削除
                    if let lastMessage = self.messages.last, lastMessage.content == "考え中..." {
                        self.messages.removeLast()
                    }
                    
                    switch result {
                    case .success(let response):
                        completion(response)
                    case .failure(let error):
                        completion("申し訳ありません、エラーが発生しました: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // URLから画像を読み込む補助メソッド
    private func loadImageFromURL(_ url: URL) -> UIImage? {
        do {
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            print("画像の読み込みエラー: \(error)")
            return nil
        }
    }
    
    // 古いDify用メソッド（互換性のために残していますが使用しないでください）
    private func runDifyWorkflow(fileId: String?, text: String) {
        print("警告: 古いrunDifyWorkflowメソッドが呼び出されました。代わりにGemini APIを使用してください。")
        // 「互換性のないAPIです」というメッセージを表示
        DispatchQueue.main.async {
            let errorMessage = Message(content: "申し訳ありませんが、このAPIは現在利用できません。", image: nil, isFromUser: false, timestamp: Date())
            messages.append(errorMessage)
        }
    }
}
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            // AIのメッセージ（左寄せ）
            if !message.isFromUser {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    if let content = message.content {
                        Text(content)
                            .padding(10)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(15)
                    }
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(15)
                    }
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer() // 右側にスペースを追加して左寄せを強調
            }
            
            // ユーザーのメッセージ（右寄せ）
            if message.isFromUser {
                Spacer() // 左側にスペースを追加して右寄せを強調
                
                VStack(alignment: .trailing) {
                    if let content = message.content {
                        Text(content)
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(15)
                    }
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 全体を画面幅いっぱいに広げて左寄せ基準にする
        .padding(.horizontal, 8) // 左右に少し余白を追加
    }
}

#Preview {
    ChatBotView()
}
