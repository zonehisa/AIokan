import SwiftUI

struct Task: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var duration: TimeInterval? // タスクの所要時間（オプション）
    var color: Color = .orange // タスクの色（カスタマイズ可能）
}

struct TimelineView: View {
    @State private var tasks: [Task] = []
    @State private var showingAddTask = false
    @State private var selectedDate = Date()
    
    private let hourHeight: CGFloat = 60
    private let timeRange = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!...Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
    
    var body: some View {
        NavigationView {
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
                                if let dueDate = task.dueDate {
                                    TimelineTaskView(task: task)
                                        .position(x: 200, y: calculateYPosition(for: dueDate))
                                }
                            }
                        }
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Button(action: { moveDate(by: -1) }) {
                            Image(systemName: "chevron.left")
                        }
                        
                        Text(selectedDate, style: .date)
                            .font(.headline)
                        
                        Button(action: { moveDate(by: 1) }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                Text("タスク追加")
            }
        }
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
}

struct TimelineHourRow: View {
    let hour: Int
    let hourHeight: CGFloat
    
    var body: some View {
        HStack {
            Text("\(hour):00")
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
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.2))
                .frame(width: 150, height: 40)
                .overlay(
                    Text(task.title)
                        .font(.caption)
                        .foregroundColor(.black)
                )
        }
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


