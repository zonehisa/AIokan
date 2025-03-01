import SwiftUI

// 共通のタスク追加画面コンポーネント
struct SharedAddTaskView: View {
    let viewTitle: String
    let onAddTask: (String, String?, Date?, TaskPriority, Int?, Date?) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(24 * 60 * 60)
    @State private var scheduledTime: Date = Date().addingTimeInterval(60 * 60)
    @State private var showDueDate: Bool = false
    @State private var showScheduledTime: Bool = false
    @State private var priority: TaskPriority = .medium
    @State private var estimatedTime: String = "60"
    @Environment(\.presentationMode) var presentationMode
    
    // 日本のタイムゾーンを設定
    private let japanTimeZone = TimeZone(identifier: "Asia/Tokyo")!
    
    init(
        viewTitle: String = "新しいタスク",
        onAddTask: @escaping (String, String?, Date?, TaskPriority, Int?, Date?) -> Void
    ) {
        self.viewTitle = viewTitle
        self.onAddTask = onAddTask
        
        // DatePickerで使用するCalendarの設定
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP")
        // UIDatePickerのデフォルト設定を変更
        UIDatePicker.appearance().timeZone = TimeZone(identifier: "Asia/Tokyo")
        UIDatePicker.appearance().calendar = calendar
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タスク情報")) {
                    TextField("タイトル", text: $title)
                    
                    TextField("説明（任意）", text: $description)
                        .frame(height: 100)
                    
                    TextField("予定時間（分）", text: $estimatedTime)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("スケジュール")) {
                    Toggle("予定実行時間を設定", isOn: $showScheduledTime)
                    
                    if showScheduledTime {
                        DatePicker("予定実行時間", selection: $scheduledTime)
                            .datePickerStyle(GraphicalDatePickerStyle())
                    }
                    
                    Toggle("期限を設定", isOn: $showDueDate)
                    
                    if showDueDate {
                        DatePicker("期限", selection: $dueDate)
                            .datePickerStyle(GraphicalDatePickerStyle())
                    }
                }
                
                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Button(action: {
                    addTask()
                }) {
                    Text("タスクを追加")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(title.isEmpty)
                .buttonStyle(BorderlessButtonStyle())
                .listRowInsets(EdgeInsets())
                .padding()
            }
            .navigationTitle(viewTitle)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("追加") {
                    addTask()
                }
                .disabled(title.isEmpty)
            )
        }
    }
    
    private func addTask() {
        let estimatedTimeInt = Int(estimatedTime) ?? 60
        
        let dueDateValue = showDueDate ? dueDate : nil
        let scheduledTimeValue = showScheduledTime ? scheduledTime : nil
        
        onAddTask(
            title,
            description.isEmpty ? nil : description,
            dueDateValue,
            priority,
            estimatedTimeInt,
            scheduledTimeValue
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct SharedAddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        SharedAddTaskView { _, _, _, _, _, _ in
            // Preview action
        }
    }
} 
