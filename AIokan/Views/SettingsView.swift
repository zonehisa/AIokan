import SwiftUI

struct SettingsView: View {
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
                        Text("user@example.com")
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        showingLogoutAlert = true
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
                        // ログアウト処理
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
        }
    }
}

#Preview {
    SettingsView()
} 
