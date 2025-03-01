//
//  AIokanApp.swift
//  AIokan
//
//  Created by 佐藤幸久 on 2025/02/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

// ConfigurationManagerを使用するための追加インポート
import Foundation
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Firebaseの詳細設定情報を表示
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path) {
        print("Firebase設定: PROJECT_ID = \(plist["PROJECT_ID"] ?? "なし")")
        print("Firebase設定: CLIENT_ID = \(plist["CLIENT_ID"] ?? "なし")")
        print("Firebase設定: BUNDLE_ID = \(plist["BUNDLE_ID"] ?? "なし")")
        print("Firebase設定: GCM_SENDER_ID = \(plist["GCM_SENDER_ID"] ?? "なし")")
        
        // Firebaseオプションを手動で設定することで、クライアントIDとプロジェクト番号の不一致を解決する
        let options = FirebaseOptions(googleAppID: plist["GOOGLE_APP_ID"] as? String ?? "",
                                     gcmSenderID: plist["GCM_SENDER_ID"] as? String ?? "")
        options.clientID = plist["CLIENT_ID"] as? String
        options.apiKey = plist["API_KEY"] as? String
        options.projectID = plist["PROJECT_ID"] as? String
        options.storageBucket = plist["STORAGE_BUCKET"] as? String
        
        print("Firebase手動設定: options.clientID = \(options.clientID ?? "なし")")
        print("Firebase手動設定: options.projectID = \(options.projectID ?? "なし")")

        // 既存の設定をクリアして新しい設定で初期化
        FirebaseApp.configure(options: options)
        print("Firebase手動設定で初期化完了")
    } else {
        FirebaseApp.configure()
        print("Firebase通常初期化完了")
    }
    
    // Google Sign Inの設定 - SecretsファイルからクライアントIDを取得
    // 377...のクライアントIDを使用するように設定
    if let clientID = ConfigurationManager.shared.googleClientID {
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("Google認証の初期化成功: クライアントID = \(clientID)")
    } else {
        print("⚠️ Google認証の初期化に失敗: クライアントIDが見つかりません")
    }
    
    // アプリのバンドルIDを表示
    print("アプリのバンドルID: \(Bundle.main.bundleIdentifier ?? "不明")")
    
    // 通知権限をリクエスト
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            print("通知権限が許可されました")
        } else if let error = error {
            print("通知権限のリクエストに失敗しました: \(error.localizedDescription)")
        }
    }
    
    return true
  }
  
  func application(_ app: UIApplication,
                   open url: URL,
                   options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    print("アプリがURLで開かれました: \(url.absoluteString)")
    return GIDSignIn.sharedInstance.handle(url)
  }
}

@main
struct AIokanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(notificationService)
                .onOpenURL { url in
                    print("onOpenURL: \(url)")
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
