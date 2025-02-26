import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var notificationsEnabled = true
    @State private var randomNotificationsEnabled = true
    @State private var selectedNotificationStyle = 0
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("アカウント")) {
                    HStack {
                        Text("メールアドレス")
                        Spacer()
                        Text(Auth.auth().currentUser?.email ?? "未ログイン")
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Button(action: {
                        print("ログアウトボタンがタップされました")
                        // 直接ログアウト処理を実行（確認なし）
                        authService.signOut()
                    }) {
                        Text("ログアウト")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("通知設定")) {
                    Toggle("通知を有効にする", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Toggle("ランダム通知", isOn: $randomNotificationsEnabled)
                        
                        Picker("通知スタイル", selection: $selectedNotificationStyle) {
                            Text("やさしい").tag(0)
                            Text("普通").tag(1)
                            Text("厳しい").tag(2)
                        }
                    }
                }
                
                Section(header: Text("カレンダー連携")) {
                    NavigationLink(destination: Text("iCloudカレンダー設定")) {
                        Text("iCloudカレンダー")
                    }
                    
                    NavigationLink(destination: Text("Googleカレンダー設定")) {
                        Text("Googleカレンダー")
                    }
                }
                
                Section(header: Text("プレミアム")) {
                    NavigationLink(destination: Text("プレミアムプラン")) {
                        HStack {
                            Text("プレミアムプランに加入")
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                Section(header: Text("サポート")) {
                    NavigationLink(destination: Text("お問い合わせフォーム")) {
                        Text("お問い合わせ")
                    }
                    
                    NavigationLink(destination: Text("プライバシーポリシー")) {
                        Text("プライバシーポリシー")
                    }
                    
                    NavigationLink(destination: Text("利用規約")) {
                        Text("利用規約")
                    }
                }
                
                Section(footer: Text("バージョン 1.0.0")) {
                    // バージョン情報のフッター
                }
            }
            .navigationTitle("設定")
            .alert(isPresented: $showingLogoutAlert) {
                Alert(
                    title: Text("ログアウト"),
                    message: Text("本当にログアウトしますか？"),
                    primaryButton: .destructive(Text("ログアウト")) {
                        // ログアウト処理を実行
                        authService.signOut()
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
            .onAppear {
                print("SettingsView - onAppear: 認証状態 = \(authService.isAuthenticated)")
                print("現在のユーザー: \(Auth.auth().currentUser?.uid ?? "なし")")
                
                // デバッグ用：UIスレッドの状態確認
                if Thread.isMainThread {
                    print("SettingsView - onAppearはメインスレッドで実行されています")
                } else {
                    print("警告: SettingsView - onAppearがバックグラウンドスレッドで実行されています")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService()) // プレビュー用にAuthServiceを提供
} 
