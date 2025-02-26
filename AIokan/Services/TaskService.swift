//
//  TaskService.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class TaskService: ObservableObject {
    private let db = Firestore.firestore()
    private let tasksCollection = "tasks"
    
    @Published var tasks: [Task] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // タスク一覧の取得
    func fetchTasks() {
        guard let currentUser = Auth.auth().currentUser else {
            self.errorMessage = "ユーザーがログインしていません"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        // 現在のユーザーのタスクのみを取得し、更新日時の降順でソート
        db.collection(tasksCollection)
            .whereField("userId", isEqualTo: currentUser.uid)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "タスクの取得に失敗しました: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "タスクが存在しません"
                    return
                }
                
                // Firestoreのデータをタスクモデルに変換
                self.tasks = documents.compactMap { document in
                    let data = document.data()
                    return Task.fromFirestore(data)
                }
                
                print("取得したタスク: \(self.tasks.count)件")
            }
    }
    
    // タスクの追加
    func addTask(_ task: Task) -> AnyPublisher<Task, Error> {
        return Future<Task, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            // Firestoreデータに変換
            let taskData = task.toFirestore()
            
            // Firestoreに保存
            self.db.collection(self.tasksCollection).document(task.id).setData(taskData) { error in
                if let error = error {
                    print("タスク追加エラー: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                print("タスク追加成功: \(task.id)")
                promise(.success(task))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // タスクの更新
    func updateTask(_ task: Task) -> AnyPublisher<Task, Error> {
        return Future<Task, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            // 更新日時を現在に設定
            var updatedTask = task
            updatedTask.updatedAt = Date()
            
            // Firestoreデータに変換
            let taskData = updatedTask.toFirestore()
            
            // Firestoreを更新
            self.db.collection(self.tasksCollection).document(task.id).updateData(taskData) { error in
                if let error = error {
                    print("タスク更新エラー: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                print("タスク更新成功: \(task.id)")
                promise(.success(updatedTask))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // タスクの削除
    func deleteTask(_ taskId: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            self.db.collection(self.tasksCollection).document(taskId).delete { error in
                if let error = error {
                    print("タスク削除エラー: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                print("タスク削除成功: \(taskId)")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // タスクのステータス変更
    func updateTaskStatus(taskId: String, status: TaskStatus) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            let data: [String: Any] = [
                "status": status.rawValue,
                "updatedAt": Timestamp(date: Date())
            ]
            
            self.db.collection(self.tasksCollection).document(taskId).updateData(data) { error in
                if let error = error {
                    print("タスクステータス更新エラー: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                print("タスクステータス更新成功: \(taskId) -> \(status.rawValue)")
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 特定のタスクを取得
    func fetchTask(taskId: String) -> AnyPublisher<Task, Error> {
        return Future<Task, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            self.db.collection(self.tasksCollection).document(taskId).getDocument { snapshot, error in
                if let error = error {
                    print("タスク取得エラー: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists,
                      let data = snapshot.data(),
                      let task = Task.fromFirestore(data) else {
                    let error = NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "タスクが見つかりませんでした"])
                    promise(.failure(error))
                    return
                }
                
                print("タスク取得成功: \(taskId)")
                promise(.success(task))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 今週のタスクを取得
    func fetchWeeklyTasks() -> AnyPublisher<[Task], Error> {
        return Future<[Task], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            guard let currentUser = Auth.auth().currentUser else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません"])))
                return
            }
            
            // 週の開始日と終了日を計算
            let calendar = Calendar.current
            let today = Date()
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? today
            
            self.db.collection(self.tasksCollection)
                .whereField("userId", isEqualTo: currentUser.uid)
                .whereField("dueDate", isGreaterThanOrEqualTo: Timestamp(date: startOfWeek))
                .whereField("dueDate", isLessThan: Timestamp(date: endOfWeek))
                .order(by: "dueDate", descending: false)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("週間タスク取得エラー: \(error.localizedDescription)")
                        promise(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        promise(.success([]))
                        return
                    }
                    
                    let tasks = documents.compactMap { document in
                        let data = document.data()
                        return Task.fromFirestore(data)
                    }
                    
                    print("取得した週間タスク: \(tasks.count)件")
                    promise(.success(tasks))
                }
        }
        .eraseToAnyPublisher()
    }
    
    // 今日のタスクを取得
    func fetchTodayTasks() -> AnyPublisher<[Task], Error> {
        return Future<[Task], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            guard let currentUser = Auth.auth().currentUser else {
                promise(.failure(NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません"])))
                return
            }
            
            // 今日の日付範囲を計算
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
            
            self.db.collection(self.tasksCollection)
                .whereField("userId", isEqualTo: currentUser.uid)
                .whereField("dueDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("dueDate", isLessThan: Timestamp(date: endOfDay))
                .order(by: "dueDate", descending: false)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("今日のタスク取得エラー: \(error.localizedDescription)")
                        promise(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        promise(.success([]))
                        return
                    }
                    
                    let tasks = documents.compactMap { document in
                        let data = document.data()
                        return Task.fromFirestore(data)
                    }
                    
                    print("取得した今日のタスク: \(tasks.count)件")
                    promise(.success(tasks))
                }
        }
        .eraseToAnyPublisher()
    }
} 
