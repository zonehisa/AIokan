//
//  ContentView.swift
//  AIokan
//
//  Created by 佐藤幸久 on 2025/02/26.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    // 新たにインスタンスを作成せず、親から提供されるEnvironmentObjectを使用
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            // 認証状態をログに出力
            print("ContentView onAppear - 認証状態: \(authService.isAuthenticated)")
            print("現在のユーザー: \(String(describing: Auth.auth().currentUser?.uid))")
        }
    }
}

#Preview {
    ContentView()
}
