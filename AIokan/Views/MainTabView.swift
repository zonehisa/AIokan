import SwiftUI

struct MainTabView: View {
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
    }
}

#Preview {
    MainTabView()
} 
