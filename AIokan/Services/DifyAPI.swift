import Foundation
import UIKit

enum APIError: Error {
    case invalidURL
    case noData
    case invalidResponse
    case uploadFailed
}

struct DifyAPI {
    // Difyのファイルアップロードエンドポイント (例: https://api.dify.ai/v1/files/upload)
    static let fileUploadEndpoint = "https://api.dify.ai/v1/files/upload"

    // ワークフロー実行のエンドポイント例 (必要なら)
    static let workflowEndpoint = "https://api.dify.ai/v1/workflows/run"

    /// DifyのファイルアップロードAPIを使って画像をアップロードする
    /// - Parameters:
    ///   - image: アップロードしたい UIImage
    ///   - searchable: 画像を全文検索対象にする場合は 1（true）、しない場合は 0（false）
    ///   - completion: 成功時は JSON の内容(例: ["id": ..., "name": ...])、失敗時はエラーを返す
    static func uploadImage(image: UIImage,
                            searchable: Bool = true,
                            completion: @escaping (Result<[String: Any], Error>) -> Void) {

        guard let url = URL(string: fileUploadEndpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }

        // UIImage を JPEG に変換
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(APIError.uploadFailed))
            return
        }

        // マルチパートフォームデータの boundary
        let boundary = "Boundary-\(UUID().uuidString)"

        // multipart/form-data のボディを組み立てる
        var body = Data()

        // 1. searchable フィールド
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"searchable\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(searchable ? 1 : 0)\r\n".data(using: .utf8)!)

        // 2. file フィールド
        let filename = "upload.jpg"
        let mimeType = "image/jpeg"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // 終了 boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // URLRequest の設定
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Secrets.difyAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        // 通信開始
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            // レスポンス文字列をログ出力
            if let responseString = String(data: data, encoding: .utf8) {
                print("アップロードレスポンス: \(responseString)")
            }

            // JSONパース
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    // 正常時は {"id":..., "name":..., "size":..., ...} のようなJSONが返る想定
                    completion(.success(json))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// ワークフロー実行のサンプル（画像の file_id を inputs に渡す例）
    static func runWorkflow(fileId: String?, text: String, completion: @escaping (Result<String, Error>) -> Void) {

        guard let url = URL(string: workflowEndpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }

        // ワークフローが想定している入力に合わせて "inputs" を構築
        var inputs: [String: Any] = [
            "text": text
        ]

        // 画像を使うワークフローの場合は file_id を渡す
        if let fileId = fileId {
            inputs["file_id"] = fileId
        }

        // リクエストボディ例
        let body: [String: Any] = [
            "inputs": inputs,
            "user": "user_1234"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Secrets.difyAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("ワークフロー実行レスポンス: \(responseString)")
            }

            // JSONパース後、実際のキーに合わせて取り出す
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    // 例: "data" -> "outputs" -> "text" に返信が入っている場合
                    if let dataDict = json["data"] as? [String: Any],
                       let outputs = dataDict["outputs"] as? [String: Any],
                       let replyText = outputs["text"] as? String {
                        completion(.success(replyText))
                        return
                    }

                    // 他のパターンを探す (replyキー、choicesなど)
                    // ...

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
