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
    // Gemini 1.5 Flashモデルのエンドポイント
    static let textGenerationEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    static let visionGenerationEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-vision:generateContent"
    
    // APIキーの取得メソッド
    private static func getAPIKey() -> String? {
        return ConfigurationManager.shared.geminiAPIKey
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
        
        // リクエストボディを作成 - Gemini 2.0向けに最適化
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
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
                print("Gemini 1.5 Flash APIレスポンス: \(responseString)")
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
    static func generateFromImageAndText(prompt: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
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
        
        // リクエストボディを作成 - Gemini 2.0向けに最適化
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
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
                print("Gemini 1.5 Flash Vision APIレスポンス: \(responseString)")
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
