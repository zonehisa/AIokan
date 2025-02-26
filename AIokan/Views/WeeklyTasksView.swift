import SwiftUI
import FirebaseAuth
import Combine

class WeeklyTasksViewModel: ObservableObject {
    @Published var selectedFilter: TaskStatus?
    @Published var searchText: String = ""
    @Published var showAddTask: Bool = false
    @Published var isLoadingTasks: Bool = false
    
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
    
    var filteredTasks: [Task] {
        var filtered = tasks
        
        // ステータスでフィルタリング
        if let status = selectedFilter {
            filtered = filtered.filter { $0.status == status }
        }
        
        // 検索テキストでフィルタリング
        if !searchText.isEmpty {
            filtered = filtered.filter { task in
                task.title.lowercased().contains(searchText.lowercased()) ||
                (task.description?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        return filtered
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
    
    func deleteTask(at indexSet: IndexSet) {
        let tasksToDelete = indexSet.map { filteredTasks[$0] }
        
        for task in tasksToDelete {
            taskService.deleteTask(task.id)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("タスク削除エラー: \(error.localizedDescription)")
                    }
                }, receiveValue: { _ in
                    print("タスクが正常に削除されました: \(task.id)")
                })
                .store(in: &cancellables)
        }
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
}

struct WeeklyTasksView: View {
    @StateObject private var viewModel = WeeklyTasksViewModel()
    @State private var editingTask: Task?
    
    var body: some View {
        NavigationView {
            VStack {
                // フィルター部分
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        FilterButton(
                            title: "すべて",
                            isSelected: viewModel.selectedFilter == nil,
                            action: { viewModel.selectedFilter = nil }
                        )
                        
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            FilterButton(
                                title: status.displayName,
                                isSelected: viewModel.selectedFilter == status,
                                action: { viewModel.selectedFilter = status }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("タスクを検索", text: $viewModel.searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if viewModel.isLoadingTasks {
                    ProgressView()
                        .padding()
                } else if viewModel.filteredTasks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("タスクがありません")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            viewModel.showAddTask = true
                        }) {
                            Text("タスクを追加")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.top, 50)
                } else {
                    List {
                        ForEach(viewModel.filteredTasks) { task in
                            NavigationLink(destination: TaskDetailView(task: task)) {
                                TaskRowView(task: task) {
                                    viewModel.updateTaskStatus(task: task, status: .completed)
                                }
                            }
                        }
                        .onDelete(perform: viewModel.deleteTask)
                    }
                }
            }
            .navigationTitle("今週のタスク")
            .navigationBarItems(
                trailing: Button(action: {
                    viewModel.showAddTask = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $viewModel.showAddTask) {
                WeeklyAddTaskView { title, description, dueDate, priority in
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
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .blue : .primary)
                .cornerRadius(20)
        }
    }
}

struct TaskRowView: View {
    let task: Task
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            // 優先度を示すマーカー
            Circle()
                .fill(Color(task.priority.color))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.status == .completed)
                    .foregroundColor(task.status == .completed ? .gray : .primary)
                
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                HStack {
                    if let dueDate = task.dueDate {
                        Text(formatDate(dueDate))
                            .font(.caption)
                            .foregroundColor(isDueDateNear(dueDate) ? .red : .gray)
                    }
                    
                    Spacer()
                    
                    Text(task.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor(for: task.status))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            if task.status != .completed {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func isDueDateNear(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour], from: now, to: date)
        return (components.hour ?? 0) <= 24 && date > now
    }
    
    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .inProgress:
            return .blue
        case .completed:
            return .green
        }
    }
}

// タスク追加画面
struct WeeklyAddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(60 * 60 * 24) // 明日
    @State private var showDatePicker: Bool = false
    @State private var selectedPriority: TaskPriority = .medium
    
    let onAddTask: (String, String?, Date?, TaskPriority) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タスク情報")) {
                    TextField("タイトル", text: $title)
                    
                    TextField("説明（任意）", text: $description)
                        .frame(height: 100)
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
        onAddTask(
            title,
            description.isEmpty ? nil : description,
            showDatePicker ? dueDate : nil,
            selectedPriority
        )
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    WeeklyTasksView()
} 
