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
    FirebaseApp.configure()
    
    // Google Sign Inの設定 - clientIDを取得
    if let clientID = ConfigurationManager.shared.googleClientID {
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
    
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
