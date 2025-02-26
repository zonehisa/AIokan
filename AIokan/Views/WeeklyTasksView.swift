import SwiftUI

struct WeeklyTasksView: View {
    @State private var selectedFilter: TaskFilter = .all
    
    enum TaskFilter {
        case all, today, tomorrow, thisWeek
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // フィルターセグメント
                Picker("タスクフィルター", selection: $selectedFilter) {
                    Text("すべて").tag(TaskFilter.all)
                    Text("今日").tag(TaskFilter.today)
                    Text("明日").tag(TaskFilter.tomorrow)
                    Text("今週").tag(TaskFilter.thisWeek)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                List {
                    Section(header: Text("未完了")) {
                        ForEach(0..<5) { _ in
                            WeeklyTaskRow()
                        }
                    }
                    
                    Section(header: Text("完了済み")) {
                        ForEach(0..<3) { _ in
                            WeeklyTaskRow(isCompleted: true)
                        }
                    }
                }
            }
            .navigationTitle("今週のタスク")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // フィルター設定
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

struct WeeklyTaskRow: View {
    var isCompleted: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("タスクのタイトル")
                    .strikethrough(isCompleted)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text("2024/02/26")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    Text("10:00")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if !isCompleted {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WeeklyTasksView()
} 
