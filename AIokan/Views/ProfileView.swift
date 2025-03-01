import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var userService = UserService()
    @State private var isEditing = false
    @State private var displayName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("アカウント情報")) {
                    if let user = Auth.auth().currentUser {
                        HStack {
                            Text("メールアドレス")
                            Spacer()
                            Text(user.email ?? "未設定")
                                .foregroundColor(.gray)
                        }
                        
                        if let profile = userService.currentUserProfile {
                            if isEditing {
                                TextField("表示名", text: $displayName)
                            } else {
                                HStack {
                                    Text("表示名")
                                    Spacer()
                                    Text(profile.displayName ?? "未設定")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            HStack {
                                Text("アカウント作成日")
                                Spacer()
                                Text(formattedDate(profile.createdAt))
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Text("最終ログイン")
                                Spacer()
                                Text(formattedDate(profile.lastLoginAt))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section(header: Text("統計情報")) {
                    HStack {
                        Text("完了タスク数")
                        Spacer()
                        Text("0")  // 実際のデータに置き換える
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("進行中タスク数")
                        Spacer()
                        Text("0")  // 実際のデータに置き換える
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    Button(action: {
                        authService.signOut()
                    }) {
                        Text("ログアウト")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarItems(trailing: 
                Button(action: {
                    if isEditing {
                        saveProfile()
                    }
                    isEditing.toggle()
                }) {
                    Text(isEditing ? "保存" : "編集")
                }
            )
            .onAppear {
                if let user = Auth.auth().currentUser {
                    userService.fetchUserProfile(userId: user.uid)
                }
            }
            .onChange(of: userService.currentUserProfile) { profile in
                if let profile = profile {
                    displayName = profile.displayName ?? ""
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let user = Auth.auth().currentUser,
              var profile = userService.currentUserProfile else {
            return  
        }
        
        profile.displayName = displayName
        
        userService.updateUserProfile(userProfile: profile)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("プロファイル更新エラー: \(error.localizedDescription)")
                }
            }, receiveValue: { _ in
                print("プロファイルを更新しました")
            })
            .store(in: &userService.cancellables)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthService())
    }
} 
