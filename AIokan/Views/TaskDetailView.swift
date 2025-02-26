//
//  TaskDetailView.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import SwiftUI
import Combine

class TaskDetailViewModel: ObservableObject {
    @Published var task: Task
    @Published var isEditing: Bool = false
    @Published var editedTitle: String
    @Published var editedDescription: String
    @Published var editedDueDate: Date?
    @Published var editedPriority: TaskPriority
    @Published var editedStatus: TaskStatus
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    
    private var taskService = TaskService()
    var cancellables = Set<AnyCancellable>()
    
    init(task: Task) {
        self.task = task
        self.editedTitle = task.title
        self.editedDescription = task.description ?? ""
        self.editedDueDate = task.dueDate
        self.editedPriority = task.priority
        self.editedStatus = task.status
    }
    
    func updateTask() {
        isSaving = true
        
        var updatedTask = task
        updatedTask.title = editedTitle
        updatedTask.description = editedDescription.isEmpty ? nil : editedDescription
        updatedTask.dueDate = editedDueDate
        updatedTask.priority = editedPriority
        updatedTask.status = editedStatus
        updatedTask.updatedAt = Date()
        
        taskService.updateTask(updatedTask)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isSaving = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "更新に失敗しました: \(error.localizedDescription)"
                    print("タスク更新エラー: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] _ in
                print("タスクが正常に更新されました")
                self?.task = updatedTask
                self?.isEditing = false
            })
            .store(in: &cancellables)
    }
    
    func updateTaskStatus(status: TaskStatus) {
        taskService.updateTaskStatus(taskId: task.id, status: status)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "ステータス更新に失敗しました: \(error.localizedDescription)"
                    print("タスクステータス更新エラー: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] _ in
                print("タスクステータスが正常に更新されました: \(status.rawValue)")
                self?.task.status = status
            })
            .store(in: &cancellables)
    }
    
    func deleteTask() -> AnyPublisher<Void, Error> {
        return taskService.deleteTask(task.id)
    }
    
    func setEditing(_ editing: Bool) {
        if editing {
            // 編集モードに入る時に現在のタスク情報をコピー
            editedTitle = task.title
            editedDescription = task.description ?? ""
            editedDueDate = task.dueDate
            editedPriority = task.priority
            editedStatus = task.status
        }
        isEditing = editing
    }
}

struct TaskDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var showingDeleteConfirmation = false
    
    init(task: Task) {
        _viewModel = StateObject(wrappedValue: TaskDetailViewModel(task: task))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー部分（タイトルと優先度）
                headerSection
                
                Divider()
                
                // 説明部分
                descriptionSection
                
                Divider()
                
                // ステータスと期限
                statusAndDueDateSection
                
                Divider()
                
                // 編集中の場合は保存ボタン、そうでない場合はアクションボタン
                if viewModel.isEditing {
                    saveButtonSection
                } else {
                    actionButtonsSection
                }
            }
            .padding()
            .navigationTitle(viewModel.isEditing ? "タスク編集" : "タスク詳細")
            .navigationBarItems(
                trailing: viewModel.isEditing
                    ? Button("キャンセル") { viewModel.setEditing(false) }
                    : Button("編集") { viewModel.setEditing(true) }
            )
            .actionSheet(isPresented: $showingDeleteConfirmation) {
                ActionSheet(
                    title: Text("タスクを削除"),
                    message: Text("このタスクを削除してもよろしいですか？この操作は元に戻せません。"),
                    buttons: [
                        .destructive(Text("削除")) {
                            deleteTask()
                        },
                        .cancel()
                    ]
                )
            }
            .alert(item: Binding<TaskError?>(
                get: { viewModel.errorMessage.map { TaskError(message: $0) } },
                set: { viewModel.errorMessage = $0?.message }
            )) { error in
                Alert(
                    title: Text("エラー"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            if viewModel.isEditing {
                VStack(alignment: .leading) {
                    Text("タイトル")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("タイトルを入力", text: $viewModel.editedTitle)
                        .font(.title2)
                        .padding(.vertical, 5)
                        .background(Color(.systemGray6))
                        .cornerRadius(5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(viewModel.task.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if viewModel.isEditing {
                Picker("優先度", selection: $viewModel.editedPriority) {
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
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
            } else {
                HStack {
                    Circle()
                        .fill(Color(viewModel.task.priority.color))
                        .frame(width: 12, height: 12)
                    Text(viewModel.task.priority.displayName)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("説明")
                .font(.headline)
            
            if viewModel.isEditing {
                TextEditor(text: $viewModel.editedDescription)
                    .frame(height: 120)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(5)
            } else {
                Text(viewModel.task.description ?? "説明はありません")
                    .foregroundColor(viewModel.task.description == nil ? .gray : .primary)
                    .padding(.vertical, 5)
            }
        }
    }
    
    private var statusAndDueDateSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            // ステータス
            VStack(alignment: .leading, spacing: 5) {
                Text("ステータス")
                    .font(.headline)
                
                if viewModel.isEditing {
                    Picker("ステータス", selection: $viewModel.editedStatus) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } else {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor(for: viewModel.task.status))
                            .frame(width: 16, height: 16)
                        
                        Text(viewModel.task.status.displayName)
                            .font(.body)
                    }
                    .padding(.vertical, 5)
                }
            }
            
            // 期限
            VStack(alignment: .leading, spacing: 5) {
                Text("期限")
                    .font(.headline)
                
                if viewModel.isEditing {
                    Toggle("期限を設定", isOn: Binding<Bool>(
                        get: { viewModel.editedDueDate != nil },
                        set: { if !$0 { viewModel.editedDueDate = nil } }
                    ))
                    
                    if viewModel.editedDueDate != nil {
                        DatePicker(
                            "期限日時",
                            selection: Binding<Date>(
                                get: { viewModel.editedDueDate ?? Date() },
                                set: { viewModel.editedDueDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } else if let dueDate = viewModel.task.dueDate {
                    Text(formatDate(dueDate))
                        .font(.body)
                        .foregroundColor(isDueDateNear(dueDate) ? .red : .primary)
                        .padding(.vertical, 5)
                } else {
                    Text("設定なし")
                        .foregroundColor(.gray)
                        .padding(.vertical, 5)
                }
            }
            
            // 作成日・更新日
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("作成日:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(formatDate(viewModel.task.createdAt))
                        .font(.subheadline)
                }
                
                HStack {
                    Text("更新日:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(formatDate(viewModel.task.updatedAt))
                        .font(.subheadline)
                }
            }
            .padding(.top, 15)
        }
    }
    
    private var saveButtonSection: some View {
        VStack {
            Button(action: {
                viewModel.updateTask()
            }) {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("保存")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(viewModel.editedTitle.isEmpty || viewModel.isSaving)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 15) {
            // 完了ボタン（タスクが完了していない場合のみ）
            if viewModel.task.status != .completed {
                Button(action: {
                    viewModel.updateTaskStatus(status: .completed)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("完了にする")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // ステータス変更ボタン
            if viewModel.task.status == .pending {
                Button(action: {
                    viewModel.updateTaskStatus(status: .inProgress)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("進行中にする")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else if viewModel.task.status == .inProgress {
                Button(action: {
                    viewModel.updateTaskStatus(status: .pending)
                }) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("保留にする")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else if viewModel.task.status == .completed {
                Button(action: {
                    viewModel.updateTaskStatus(status: .inProgress)
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("再開する")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // 削除ボタン
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("削除")
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private func deleteTask() {
        viewModel.deleteTask()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("タスク削除エラー: \(error.localizedDescription)")
                    viewModel.errorMessage = "削除に失敗しました: \(error.localizedDescription)"
                }
            }, receiveValue: {
                print("タスクが正常に削除されました")
                presentationMode.wrappedValue.dismiss()
            })
            .store(in: &viewModel.cancellables)
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

// エラーメッセージを表示するためのIdentifiableラッパー
struct TaskError: Identifiable {
    let id = UUID()
    let message: String
}

struct TaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TaskDetailView(task: Task(
                title: "サンプルタスク",
                description: "これはサンプルタスクの説明です。",
                dueDate: Date().addingTimeInterval(60 * 60 * 24),
                priority: .high,
                userId: "sample-user-id"
            ))
        }
    }
} 
