import Foundation

/// アプリの設定（通常の設定と機密情報）を管理するクラス
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    // OAuth認証用のクライアントID
    var googleClientID: String? {
        return loadSecretValue(for: "GIDClientID") as? String
    }
    
    // URLスキーム
    var googleURLScheme: String? {
        if let urlTypes = loadSecretValue(for: "CFBundleURLTypes") as? [[String: Any]],
           let firstUrlType = urlTypes.first,
           let urlSchemes = firstUrlType["CFBundleURLSchemes"] as? [String],
           let scheme = urlSchemes.first {
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
