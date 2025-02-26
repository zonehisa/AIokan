import SwiftUI

struct Task: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var duration: TimeInterval? = 60 * 60 // デフォルト1時間（秒単位）
    var color: Color = .blue // タスクの色（カスタマイズ可能）
}

struct TimelineView: View {
    @State private var tasks: [Task] = [
        Task(title: "プレゼン資料作成", isCompleted: false, dueDate: Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()), duration: 120 * 60),
        Task(title: "買い物に行く", isCompleted: false, dueDate: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()), duration: 60 * 60)
    ]
    @State private var showingAddTask = false
    @State private var selectedDate = Date()
    @State private var draggedTaskID: UUID? = nil
    @State private var draggedTaskOffset: CGFloat = 0
    
    private let hourHeight: CGFloat = 60
    private let timeRange = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!...Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // タイムライン部分
                            ZStack(alignment: .topLeading) {
                                // 時間軸
                                VStack(spacing: 0) {
                                    ForEach(0..<24) { hour in
                                        TimelineHourRow(hour: hour, hourHeight: hourHeight)
                                    }
                                }
                                
                                // タスク表示
                                ForEach(tasks) { task in
                                    if let dueDate = task.dueDate, let duration = task.duration {
                                        let yPosition = calculateYPosition(for: dueDate)
                                        let offset = (draggedTaskID == task.id) ? draggedTaskOffset : 0
                                        
                                        TimelineTaskView(task: task)
                                            .frame(width: geometry.size.width * 0.7, height: calculateHeight(for: duration))
                                            .position(
                                                x: geometry.size.width * 0.5,
                                                y: yPosition + calculateHeight(for: duration) / 2 + offset
                                            )
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        draggedTaskID = task.id
                                                        draggedTaskOffset = value.translation.height
                                                    }
                                                    .onEnded { value in
                                                        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                                                            // 移動した位置から新しい時間を計算
                                                            let newPosition = yPosition + value.translation.height
                                                            let newHour = Int(newPosition / hourHeight)
                                                            let newMinute = Int((newPosition.truncatingRemainder(dividingBy: hourHeight) / hourHeight) * 60)
                                                            
                                                            // 有効な時間範囲内かチェック
                                                            if newHour >= 0 && newHour < 24 {
                                                                // 新しい日時を作成
                                                                var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
                                                                components.hour = newHour
                                                                components.minute = newMinute
                                                                
                                                                if let newDate = Calendar.current.date(from: components) {
                                                                    // タスクを更新
                                                                    var updatedTask = task
                                                                    updatedTask.dueDate = newDate
                                                                    tasks[index] = updatedTask
                                                                }
                                                            }
                                                        }
                                                        
                                                        // ドラッグ状態をリセット
                                                        draggedTaskID = nil
                                                        draggedTaskOffset = 0
                                                    }
                                            )
                                    }
                                }
                            }
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
                
                // 右下のプラスボタン
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.blue))
                        .shadow(radius: 3)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Button(action: { moveDate(by: -1) }) {
                            Image(systemName: "chevron.left")
                        }
                        
                        Text(formattedDate)
                            .font(.headline)
                        
                        Button(action: { moveDate(by: 1) }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                Text("タスク追加")
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: selectedDate)
    }
    
    private func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func calculateYPosition(for date: Date) -> CGFloat {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        return CGFloat(hour) * hourHeight + CGFloat(minute) * hourHeight / 60
    }
    
    private func calculateHeight(for duration: TimeInterval) -> CGFloat {
        // 秒単位の時間を時間単位に変換して高さを計算
        return CGFloat(duration / 3600) * hourHeight
    }
}

struct TimelineHourRow: View {
    let hour: Int
    let hourHeight: CGFloat
    
    var body: some View {
        HStack {
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .frame(width: 50)
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
        }
        .frame(height: hourHeight)
    }
}

struct TimelineTaskView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .center) {
            Text(task.title)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, 4)
            
            if let duration = task.duration {
                Text("\(Int(duration / 60))分")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(task.color)
        )
    }
}

struct TaskRow: View {
    let task: Task
    
    var body: some View {
        HStack {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                
                if let dueDate = task.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

#Preview {
    TimelineView()
} 


