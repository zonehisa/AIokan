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

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // Google Sign Inの設定 - clientIDを取得
    if let clientID = ConfigurationManager.shared.googleClientID {
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .onOpenURL { url in
                    print("onOpenURL: \(url)")
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
