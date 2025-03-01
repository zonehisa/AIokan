import Foundation

/// アプリの設定（通常の設定と機密情報）を管理するクラス
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    // OAuth認証用のクライアントID
    var googleClientID: String? {
        // 1. Secretsファイルから値を取得して優先する (377...)
        if let secretClientID = loadSecretValue(for: "GIDClientID") as? String {
            print("ConfigurationManager: Secretsから取得したクライアントID = \(secretClientID)")
            return secretClientID
        }
        
        // 2. バックアップとしてFirebaseの設定ファイルを確認 (212...)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String {
            print("ConfigurationManager: FirebaseからバックアップとしてのクライアントID = \(clientID)")
            return clientID
        }
        
        print("ConfigurationManager: クライアントIDを取得できませんでした")
        return nil
    }
    
    // URLスキーム
    var googleURLScheme: String? {
        if let urlTypes = loadSecretValue(for: "CFBundleURLTypes") as? [[String: Any]],
           let firstUrlType = urlTypes.first,
           let urlSchemes = firstUrlType["CFBundleURLSchemes"] as? [String],
           let scheme = urlSchemes.first {
            print("ConfigurationManager: URLスキーム = \(scheme)")
            return scheme
        }
        return nil
    }
    
    // Secretsファイルから値を読み込む
    private func loadSecretValue(for key: String) -> Any? {
        guard let secretsPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let secrets = NSDictionary(contentsOfFile: secretsPath) else {
            print("⚠️ Secrets.plistファイルが見つかりませんでした。")
            return nil
        }
        
        return secrets[key]
    }
} 
