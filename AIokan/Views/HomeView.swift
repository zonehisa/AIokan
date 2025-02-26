//
//  HomeView.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var userService = UserService()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("ようこそ！")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                if let user = Auth.auth().currentUser {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ユーザー情報:")
                            .font(.headline)
                        Text("メールアドレス: \(user.email ?? "不明")")
                        Text("ユーザーID: \(user.uid)")
                        
                        if let profile = userService.currentUserProfile {
                            Divider()
                            Text("プロファイル情報:")
                                .font(.headline)
                            Text("表示名: \(profile.displayName ?? "未設定")")
                            Text("作成日: \(formattedDate(profile.createdAt))")
                            Text("最終ログイン: \(formattedDate(profile.lastLoginAt))")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                }
                
                Spacer()
                
                Button(action: {
                    authService.signOut()
                }) {
                    Text("ログアウト")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("ホーム")
        }
        .onAppear {
            if let user = Auth.auth().currentUser {
                userService.fetchUserProfile(userId: user.uid)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    HomeView()
} 
