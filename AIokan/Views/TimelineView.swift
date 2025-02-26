//
//  TimelineView.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import SwiftUI
import FirebaseAuth
import Combine

class TimelineViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var showAddTask: Bool = false
    @Published var isLoadingTasks: Bool = false
    @Published var selectedTimeBlock: (start: Date, end: Date)? = nil
    
    private var taskService = TaskService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // TaskServiceの状態を監視
        taskService.$isLoading
            .assign(to: \.isLoadingTasks, on: self)
            .store(in: &cancellables)
        
        // タスク取得開始
        loadTasks()
    }
    
    var tasks: [Task] {
        taskService.tasks
    }
    
    var tasksForSelectedDate: [Task] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }
    
    func tasksByHour() -> [Int: [Task]] {
        var result = [Int: [Task]]()
        
        for task in tasksForSelectedDate {
            guard let dueDate = task.dueDate else { continue }
            let hour = Calendar.current.component(.hour, from: dueDate)
            if result[hour] == nil {
                result[hour] = [task]
            } else {
                result[hour]?.append(task)
            }
        }
        
        return result
    }
    
    func moveDate(days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    func loadTasks() {
        taskService.fetchTasks()
    }
    
    func addTask(title: String, description: String?, dueDate: Date?, priority: TaskPriority) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let newTask = Task(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority,
            userId: userId
        )
        
        taskService.addTask(newTask)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("タスク追加エラー: \(error.localizedDescription)")
                }
            }, receiveValue: { _ in
                print("タスクが正常に追加されました")
            })
            .store(in: &cancellables)
    }
    
    func updateTaskStatus(task: Task, status: TaskStatus) {
        taskService.updateTaskStatus(taskId: task.id, status: status)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("タスクステータス更新エラー: \(error.localizedDescription)")
                }
            }, receiveValue: { _ in
                print("タスクステータスが正常に更新されました: \(task.id) -> \(status.rawValue)")
            })
            .store(in: &cancellables)
    }
    
    func getHourRangeFor(hour: Int) -> (start: Date, end: Date) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = 0
        components.second = 0
        
        let startDate = Calendar.current.date(from: components) ?? selectedDate
        let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? selectedDate
        
        return (startDate, endDate)
    }
    
    func taskDuration(_ task: Task) -> Int {
        // デフォルトでは60分とする
        guard let duration = task.estimatedTime else { return 60 }
        return duration
    }
}

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日付セレクター
                HStack {
                    Button(action: {
                        viewModel.moveDate(days: -1)
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text(formatDate(viewModel.selectedDate))
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.moveDate(days: 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .padding()
                
                // 24時間タイムライン
                if viewModel.isLoadingTasks {
                    ProgressView()
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                TimeBlockView(hour: hour, tasks: viewModel.tasksByHour()[hour] ?? [])
                                Divider()
                            }
                        }
                    }
                }
            }
            .navigationTitle("タイムライン")
            .navigationBarItems(
                trailing: Button(action: {
                    viewModel.showAddTask = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $viewModel.showAddTask) {
                AddTaskView { title, description, dueDate, priority in
                    viewModel.addTask(
                        title: title,
                        description: description,
                        dueDate: dueDate,
                        priority: priority
                    )
                }
            }
            .onAppear {
                viewModel.loadTasks()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct TimeBlockView: View {
    let hour: Int
    let tasks: [Task]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 時間表示
            HStack {
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 60, alignment: .leading)
                    .padding(.leading, 10)
                
                Spacer()
            }
            .frame(height: 40)
            
            // タスク表示
            ForEach(tasks) { task in
                TaskTimelineBlockView(task: task)
                    .padding(.leading, 70)
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
            }
        }
    }
}

struct TaskTimelineBlockView: View {
    let task: Task
    
    var body: some View {
        NavigationLink(destination: TaskDetailView(task: task)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let estimatedTime = task.estimatedTime {
                    Text("\(estimatedTime)分")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .background(Color.blue)
            .cornerRadius(8)
        }
    }
}

// タスク追加画面
struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(60 * 60 * 24) // 明日
    @State private var showDatePicker: Bool = false
    @State private var selectedPriority: TaskPriority = .medium
    @State private var estimatedTime: String = "60"
    
    let onAddTask: (String, String?, Date?, TaskPriority) -> Void
    
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
                
                Section(header: Text("期限")) {
                    Toggle("期限を設定", isOn: $showDatePicker.animation())
                    
                    if showDatePicker {
                        DatePicker("期限日時", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(GraphicalDatePickerStyle())
                    }
                }
                
                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(Color(priority.color))
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
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
            .navigationTitle("新しいタスク")
            .navigationBarItems(trailing: Button("キャンセル") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func addTask() {
        var newTask = Task(
            title: title,
            description: description.isEmpty ? nil : description,
            dueDate: showDatePicker ? dueDate : nil,
            priority: selectedPriority,
            userId: ""
        )
        
        if let estimatedTimeInt = Int(estimatedTime) {
            newTask.estimatedTime = estimatedTimeInt
        }
        
        onAddTask(
            title,
            description.isEmpty ? nil : description,
            showDatePicker ? dueDate : nil,
            selectedPriority
        )
        presentationMode.wrappedValue.dismiss()
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
    }
}


