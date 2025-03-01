import Foundation
import UIKit

enum APIError: Error {
    case invalidURL
    case noData
    case invalidResponse
    case uploadFailed
    case jsonEncodingError
    case apiError(String)
}

struct GeminiAPI {
    // 会話履歴を保持する配列
    private static var conversationHistory: [[String: Any]] = []
    
    // Gemini 1.5 Pro モデルのエンドポイント（カスタムチューニングされたモデルの場合は変更してください）
    static let textGenerationEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent"
    static let visionGenerationEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent"
    
    // APIキーの取得メソッド
    private static func getAPIKey() -> String? {
        return ConfigurationManager.shared.geminiAPIKey
    }
    
    /// 会話履歴をリセットする
    static func resetConversation() {
        conversationHistory = []
        
        // システムメッセージを追加して大阪弁で応答するよう指示
        let systemMessage: [String: Any] = [
            "role": "model",
            "parts": [
                ["text": "あなたは「AIオカン」という名前の関西弁（大阪弁）を話すAIアシスタントです。このあとのすべての応答は大阪弁で行ってください。「～や」「～やで」「～やねん」「～やわ」「～ちゃう」などの表現を使い、親しみやすく温かみのある口調で話してください。ユーザーの質問に対して、役立つ情報を大阪弁で提供してください。"]
            ]
        ]
        conversationHistory.append(systemMessage)
    }
    
    /// テキスト生成API
    /// - Parameters:
    ///   - prompt: 入力テキスト
    ///   - completion: 結果のコールバック
    static func generateText(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(APIError.apiError("APIキーが設定されていません")))
            return
        }
        
        // URLを構築
        guard var urlComponents = URLComponents(string: textGenerationEndpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // クエリパラメータにAPIキーを追加
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // ユーザーの新しいメッセージを追加
        let userMessage: [String: Any] = [
            "role": "user",
            "parts": [
                ["text": prompt]
            ]
        ]
        
        // 履歴に追加
        conversationHistory.append(userMessage)
        
        // リクエストボディを作成 - 会話履歴を含める
        let requestBody: [String: Any] = [
            "contents": conversationHistory,
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048,
                "responseMimeType": "text/plain"
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_ONLY_HIGH"
                ],
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_ONLY_HIGH"
                ],
                [
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_ONLY_HIGH"
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(APIError.jsonEncodingError))
            return
        }
        
        // リクエスト実行
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            // デバッグ用：レスポンスの内容を出力
            if let responseString = String(data: data, encoding: .utf8) {
                print("Gemini API レスポンス: \(responseString)")
            }
            
            // JSONをパース
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    // エラーチェック
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(APIError.apiError(message)))
                        return
                    }
                    
                    // 成功レスポンスのパース - Gemini 2.0の応答形式に対応
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        
                        // アシスタントの応答を会話履歴に追加
                        let assistantMessage: [String: Any] = [
                            "role": "model",
                            "parts": [
                                ["text": text]
                            ]
                        ]
                        conversationHistory.append(assistantMessage)
                        
                        completion(.success(text))
                        return
                    }
                    
                    completion(.failure(APIError.invalidResponse))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// 画像とテキストを使った生成API
    /// - Parameters:
    ///   - prompt: テキストプロンプト
    ///   - image: 画像
    ///   - completion: 結果のコールバック
    static func generateFromImageAndText(prompt: String?, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(APIError.apiError("APIキーが設定されていません")))
            return
        }
        
        // URLを構築
        guard var urlComponents = URLComponents(string: visionGenerationEndpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // クエリパラメータにAPIキーを追加
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // 画像をBase64エンコード
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(APIError.uploadFailed))
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // ユーザーの新しいメッセージを作成（テキストと画像を含む）
        var userMessageParts: [[String: Any]] = [
            [
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64Image
                ]
            ]
        ]

        if let prompt = prompt, !prompt.isEmpty {
            userMessageParts.insert(["text": prompt], at: 0)
        }

        let userMessage: [String: Any] = [
            "role": "user",
            "parts": userMessageParts
        ]
        
        // 履歴に追加
        conversationHistory.append(userMessage)
        
        // リクエストボディを作成
        let requestBody: [String: Any] = [
            "contents": conversationHistory,
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048,
                "responseMimeType": "text/plain"
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_ONLY_HIGH"
                ],
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_ONLY_HIGH"
                ],
                [
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_ONLY_HIGH"
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(APIError.jsonEncodingError))
            return
        }
        
        // リクエスト実行
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            // デバッグ用：レスポンスの内容を出力
            if let responseString = String(data: data, encoding: .utf8) {
                print("Gemini API Vision レスポンス: \(responseString)")
            }
            
            // JSONをパース
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    // エラーチェック
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(APIError.apiError(message)))
                        return
                    }
                    
                    // 成功レスポンスのパース
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        
                        // アシスタントの応答を会話履歴に追加
                        let assistantMessage: [String: Any] = [
                            "role": "model",
                            "parts": [
                                ["text": text]
                            ]
                        ]
                        conversationHistory.append(assistantMessage)
                        
                        completion(.success(text))
                        return
                    }
                    
                    completion(.failure(APIError.invalidResponse))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// 古いAPIの参照との互換性のために別名を定義
typealias DifyAPI = GeminiAPI
