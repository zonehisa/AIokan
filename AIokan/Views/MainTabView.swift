import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("タイムライン")
                }
                .tag(0)
            
            WeeklyTasksView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("タスク")
                }
                .tag(1)
            
            ChatBotView()
                .tabItem {
                    Image(systemName: "message")
                    Text("AIオカン")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
                .tag(3)
        }
        .onAppear {
            print("MainTabView - onAppear: 認証状態 = \(authService.isAuthenticated)")
            print("認証済みユーザー: \(Auth.auth().currentUser?.uid ?? "なし")")
            
            // デバッグ用：UIスレッドの状態確認
            if Thread.isMainThread {
                print("MainTabView - onAppearはメインスレッドで実行されています")
            } else {
                print("警告: MainTabView - onAppearがバックグラウンドスレッドで実行されています")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
} 
