//
//  TimelineView.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import SwiftUI
import FirebaseAuth
import Combine
import UniformTypeIdentifiers

// ドラッグアイテムの型定義
struct TaskDragItem: Identifiable, Equatable {
    let id: String
    let task: Task
    let sourceHour: Int
    
    static func == (lhs: TaskDragItem, rhs: TaskDragItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// スクロール位置を追跡するためのPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// 単純化したTimelineViewModel
class TimelineViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var showAddTask: Bool = false
    @Published var isLoadingTasks: Bool = false
    @Published var currentTime: Date = Date()
    @Published var draggedTask: TaskDragItem? = nil
    @Published var isDragging: Bool = false
    @Published var dragLocation: CGPoint = .zero
    @Published var zoomLevel: CGFloat = 1.0 {
        didSet {
            // zoomLevelが変更されたらhourBlockHeightも更新
            updateHourBlockHeight()
        }
    }
    @Published var minZoom: CGFloat = 0.5
    @Published var maxZoom: CGFloat = 2.0
    @Published var hourBlockHeight: CGFloat = 150.0
    
    private var taskService = TaskService()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    var tasks: [Task] {
        taskService.tasks
    }
    
    init() {
        // TaskServiceの状態を監視
        taskService.$isLoading
            .assign(to: \.isLoadingTasks, on: self)
            .store(in: &cancellables)
        
        // タスク取得開始
        loadTasks()
        
        // 現在時刻を更新するタイマーを設定
        startTimer()
        
        // 初期設定
        updateHourBlockHeight()
    }
    
    deinit {
        stopTimer()
    }
    
    func startTimer() {
        // 1分ごとに現在時刻を更新
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.currentTime = Date()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    var tasksForSelectedDate: [Task] {
        tasks.filter { task in
            // 予定時間があれば、その日付が選択日に一致するか確認
            if let scheduledTime = task.scheduledTime {
                return Calendar.current.isDate(scheduledTime, inSameDayAs: selectedDate)
            }
            // 予定時間がなければ期限日を使用
            else if let dueDate = task.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
            }
            // どちらもなければ作成日を使用
            return Calendar.current.isDate(task.createdAt, inSameDayAs: selectedDate)
        }
    }
    
    func tasksByHour() -> [Int: [Task]] {
        var result = [Int: [Task]]()
        
        for task in tasksForSelectedDate {
            // タスクの表示時間を決定 (優先順位: 予定時間 > 期限 > 作成時間)
            let taskTime: Date
            if let scheduledTime = task.scheduledTime {
                taskTime = scheduledTime
            } else if let dueDate = task.dueDate {
                taskTime = dueDate
            } else {
                taskTime = task.createdAt
            }
            
            let hour = Calendar.current.component(.hour, from: taskTime)
            
            if result[hour] == nil {
                result[hour] = [task]
            } else {
                result[hour]?.append(task)
            }
        }
        
        return result
    }
    
    func getTaskHour(_ task: Task) -> Int {
        // タスクの時間を取得
        let taskTime: Date
        if let scheduledTime = task.scheduledTime {
            taskTime = scheduledTime
        } else if let dueDate = task.dueDate {
            taskTime = dueDate
        } else {
            taskTime = task.createdAt
        }
        
        return Calendar.current.component(.hour, from: taskTime)
    }
    
    func getTaskMinute(_ task: Task) -> Int {
        // タスクの分を取得
        let taskTime: Date
        if let scheduledTime = task.scheduledTime {
            taskTime = scheduledTime
        } else if let dueDate = task.dueDate {
            taskTime = dueDate
        } else {
            taskTime = task.createdAt
        }
        
        return Calendar.current.component(.minute, from: taskTime)
    }
    
    func moveDate(days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    func loadTasks() {
        taskService.fetchTasks()
    }
    
    func addTask(title: String, description: String?, dueDate: Date?, priority: TaskPriority, estimatedTime: Int?, scheduledTime: Date?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var newTask = Task(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority,
            userId: userId
        )
        
        // 予定時間の設定
        if let estimatedTime = estimatedTime {
            newTask.estimatedTime = estimatedTime
        }
        
        if let scheduledTime = scheduledTime {
            newTask.scheduledTime = scheduledTime
        }
        
        taskService.addTask(newTask)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("タスク追加エラー: \(error.localizedDescription)")
                }
            }, receiveValue: { _ in
                print("タスクが正常に追加されました")
            })
            .store(in: &self.cancellables)
    }
    
    func startDragging(task: Task) {
        let hour = getTaskHour(task)
        let dragItem = TaskDragItem(id: task.id, task: task, sourceHour: hour)
        self.draggedTask = dragItem
        self.isDragging = true
    }
    
    func endDragging() {
        self.draggedTask = nil
        self.isDragging = false
    }
    
    func moveTaskToHour(task: Task, toHour: Int) {
        // 基準となる日時を取得
        let taskDate: Date
        if let scheduledTime = task.scheduledTime {
            taskDate = scheduledTime
        } else if let dueDate = task.dueDate {
            taskDate = dueDate
        } else {
            taskDate = task.createdAt
        }
        
        // 分を維持して時間だけ変更
        let minute = Calendar.current.component(.minute, from: taskDate)
        
        // 新しい予定時間を生成
        var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = toHour
        components.minute = minute
        
        guard let newTime = Calendar.current.date(from: components) else {
            print("日時の設定に失敗しました")
            return
        }
        
        // タスクのコピーを作成して時間を更新
        var updatedTask = task
        updatedTask.scheduledTime = newTime
        
        // Firestoreに保存
        taskService.updateTask(updatedTask)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("タスク更新エラー: \(error.localizedDescription)")
                    }
                    
                    // ドラッグ状態をリセット
                    self.endDragging()
                },
                receiveValue: { _ in
                    print("タスク更新成功: \(task.title) → \(toHour)時")
                    
                    // バイブレーションフィードバック
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // タスクの再読み込み
                    self.loadTasks()
                }
            )
            .store(in: &self.cancellables)
    }
    
    func taskColor(for task: Task) -> Color {
        switch task.priority {
        case .high:
            return Color(UIColor.systemRed)
        case .medium:
            return Color(UIColor.systemBlue)
        case .low:
            return Color(UIColor.systemGreen)
        }
    }
    
    func zoomOut() {
        zoomLevel = max(minZoom, zoomLevel - 0.1)
    }
    
    func zoomIn() {
        zoomLevel = min(maxZoom, zoomLevel + 0.1)
    }
    
    func resetZoom() {
        zoomLevel = 1.0
    }
    
    // ズームレベルに応じて時間ブロックの高さを更新
    private func updateHourBlockHeight() {
        // 基本の高さ（150）にズームレベルを掛ける
        hourBlockHeight = 150.0 * zoomLevel
        print("ズームレベル: \(zoomLevel), 時間ブロック高さ: \(hourBlockHeight)")
    }
}

// TimelineView
struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var scrollPosition: CGFloat = 0
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // 日付セレクター
                    dateHeader
                    
                    // 24時間タイムライン
                    if viewModel.isLoadingTasks {
                        ProgressView()
                            .padding()
                    } else {
                        timelineScrollView
                    }
                }
                
                // 追加ボタン
                addButton
            }
            .navigationTitle("タイムライン")
        }
        .sheet(isPresented: $viewModel.showAddTask) {
            SharedAddTaskView(viewTitle: "新しいタスク") { title, description, dueDate, priority, estimatedTime, scheduledTime in
                viewModel.addTask(
                    title: title,
                    description: description,
                    dueDate: dueDate,
                    priority: priority,
                    estimatedTime: estimatedTime,
                    scheduledTime: scheduledTime
                )
            }
        }
        .onAppear {
            viewModel.loadTasks()
        }
        .onDisappear {
            viewModel.stopTimer()
        }
    }
    
    private var dateHeader: some View {
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
    }
    
    private var timelineScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // スクロール位置検出
                GeometryReader { geometry in
                    Color.clear.preference(key: ViewOffsetKey.self, value: geometry.frame(in: .named("scrollView")).origin.y)
                }
                .frame(height: 0)
                
                // タイムラインコンテンツ
                timelineContent
                    .background(currentTimeIndicator)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                // ズーム感度を調整（0.02を掛けることで変化を緩やかに）
                                let scaleDelta = (value - 1.0) * 0.02
                                let newScale = lastScaleValue + scaleDelta
                                
                                // 最小・最大の範囲内に制限
                                let boundedScale = min(max(newScale, viewModel.minZoom), viewModel.maxZoom)
                                
                                // ズームレベルを更新
                                currentScale = boundedScale
                                viewModel.zoomLevel = boundedScale
                                
                                // 変化が大きい場合はフィードバック
                                if abs(viewModel.zoomLevel - lastScaleValue) > 0.05 {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    lastScaleValue = viewModel.zoomLevel  // フィードバック基準を更新
                                }
                            }
                            .onEnded { _ in
                                // ズームが終了したときの処理
                                withAnimation(.easeInOut(duration: 0.1)) { // アニメーションの速度を調整
                                    lastScaleValue = viewModel.zoomLevel
                                    currentScale = viewModel.zoomLevel
                                }
                            }
                    )
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ViewOffsetKey.self) { offset in
                scrollPosition = offset
            }
            .onAppear {
                // 初期表示時に現在時刻付近にスクロール
                let currentHour = Calendar.current.component(.hour, from: Date())
                withAnimation {
                    proxy.scrollTo(max(0, currentHour - 1), anchor: .top)
                }
                
                // 初期値を設定
                currentScale = viewModel.zoomLevel
                lastScaleValue = viewModel.zoomLevel
            }
        }
    }
    
    // タイムラインのメインコンテンツ
    private var timelineContent: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                TimeBlockView(hour: hour, viewModel: viewModel)
                    .id(hour)
                    .frame(height: viewModel.hourBlockHeight)
            }
        }
    }
    
    private var currentTimeIndicator: some View {
        GeometryReader { geometry in
            if Calendar.current.isDate(viewModel.currentTime, inSameDayAs: viewModel.selectedDate) {
                let hourHeight = viewModel.hourBlockHeight
                let calendar = Calendar.current
                let hour = CGFloat(calendar.component(.hour, from: viewModel.currentTime))
                let minute = CGFloat(calendar.component(.minute, from: viewModel.currentTime))
                let position = hour * hourHeight + minute * (hourHeight / 60)
                
                HStack(spacing: 0) {
                    Text(formatCurrentTime())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.leading, 10)
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1)
                }
                .position(x: geometry.size.width / 2, y: position)
            }
        }
        .onReceive(viewModel.$currentTime) { _ in
            // 現在時刻が更新されたときに再描画をトリガー
            // ここで何もする必要はありませんが、SwiftUIが再描画を行います
        }
    }
    
    private var addButton: some View {
        Button(action: {
            viewModel.showAddTask = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .padding(.bottom, 16)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: viewModel.currentTime)
    }
}

// スクロール位置を追跡するためのPreferenceKey
struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// 時間ブロックビュー
struct TimeBlockView: View {
    let hour: Int
    @ObservedObject var viewModel: TimelineViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 時間ヘッダー
            HStack {
                Text(String(format: "%d:00", hour))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 60, alignment: .leading)
                    .padding(.leading, 10)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(height: 1)
            }
            
            // タスク表示エリア
            ZStack(alignment: .topLeading) {
                // ドロップエリア
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: viewModel.hourBlockHeight - 30) // ヘッダー分を引く
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers, location in
                        guard let draggedTask = viewModel.draggedTask else { return false }
                        
                        // タスクを指定した時間に移動
                        viewModel.moveTaskToHour(task: draggedTask.task, toHour: hour)
                        
                        // バイブレーションフィードバック
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        return true
                    }
                
                // この時間帯のタスク一覧
                ForEach(viewModel.tasksByHour()[hour] ?? [], id: \.id) { task in
                    TaskView(task: task, viewModel: viewModel)
                        .padding(.top, CGFloat(viewModel.getTaskMinute(task)) * CGFloat(viewModel.zoomLevel) * 2)  // 分に応じて配置（ズーム対応）
                        .padding(.leading, 70)  // 時間表示分の余白
                }
            }
            .frame(height: viewModel.hourBlockHeight - 30) // ヘッダー分を引く
            
            Spacer()
        }
    }
}

// タスク表示ビュー
struct TaskView: View {
    let task: Task
    @ObservedObject var viewModel: TimelineViewModel
    @State private var isDragging = false
    
    var body: some View {
        NavigationLink(destination: TaskDetailView(task: task)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    let timeText = formatTaskTime(task)
                    Text(timeText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let estimatedTime = task.estimatedTime {
                        Spacer()
                        Text("\(estimatedTime)分")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                // ステータス表示
                if task.status != .pending {
                    Text(task.status.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            task.status == .completed ? 
                                Color.green.opacity(0.8) : 
                                Color.orange.opacity(0.8)
                        )
                        .cornerRadius(4)
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(width: 220)
            .background(viewModel.taskColor(for: task).opacity(0.8))
            .cornerRadius(8)
            .shadow(radius: isDragging ? 4 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .onDrag {
            // ドラッグ開始
            viewModel.startDragging(task: task)
            withAnimation {
                isDragging = true
            }
            
            // ドラッグアイテムを返す
            return NSItemProvider(object: task.id as NSString)
        }
        .onChange(of: viewModel.isDragging) { isDragging in
            if !isDragging {
                withAnimation {
                    self.isDragging = false
                }
            }
        }
    }
    
    private func formatTaskTime(_ task: Task) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let scheduledTime = task.scheduledTime {
            return "予定: \(formatter.string(from: scheduledTime))"
        } else if let dueDate = task.dueDate {
            return "期限: \(formatter.string(from: dueDate))"
        } else {
            return "作成: \(formatter.string(from: task.createdAt))"
        }
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
    }
}


