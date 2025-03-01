import Foundation
import UserNotifications
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

class NotificationService: ObservableObject {
    
    // シングルトンインスタンス
    static let shared = NotificationService()
    
    // 通知センター
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Firestore参照
    private let db = Firestore.firestore()
    
    // 公開プロパティ
    @Published var hasNotificationPermission: Bool = false
    
    // 初期化
    private init() {
        checkNotificationPermission()
    }
    
    // MARK: - 通知権限
    
    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.hasNotificationPermission = granted
                if granted {
                    print("通知権限が許可されました")
                } else {
                    print("通知権限が拒否されました: \(String(describing: error))")
                }
            }
        }
    }
    
    private func checkNotificationPermission() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasNotificationPermission = settings.authorizationStatus == .authorized
                if self.hasNotificationPermission {
                    print("通知権限は既に許可されています")
                } else {
                    print("通知権限がありません")
                }
            }
        }
    }
    
    // MARK: - タスク通知管理
    
    // タスクの予定時間の30分前に通知をスケジュール
    func scheduleTaskNotification(for task: Task) {
        // 通知権限がなければ何もしない
        if !hasNotificationPermission {
            print("通知権限がありません。通知はスケジュールされません。")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("ユーザーIDが取得できません。通知はスケジュールされません。")
            return
        }
        
        // 既存の通知をキャンセル
        cancelExistingTaskNotifications(for: task.id)
        
        // タスクの通知時間を決定（優先順位: scheduledTime > dueDate）
        var notificationBaseTime: Date?
        var timeTypeDescription: String = ""
        
        if let scheduledTime = task.scheduledTime {
            notificationBaseTime = scheduledTime
            timeTypeDescription = "開始時間"
            print("予定時間に基づいて通知をスケジュールします: \(scheduledTime)")
        } else if let dueDate = task.dueDate {
            notificationBaseTime = dueDate
            timeTypeDescription = "期限"
            print("期限日時に基づいて通知をスケジュールします: \(dueDate)")
        }
        
        // 通知基準時間が設定されていて、未来の時間であれば通知をスケジュール
        if let baseTime = notificationBaseTime, baseTime > Date() {
            let now = Date()
            var notificationTime: Date
            var notificationMessage: String
            
            // 30分前の時間を計算
            let thirtyMinBefore = baseTime.addingTimeInterval(-30 * 60)
            
            // 通知時間と内容を設定
            if thirtyMinBefore > now {
                // 30分前が現在より未来の場合：標準の「あと30分です」通知
                notificationTime = thirtyMinBefore
                notificationMessage = "「\(task.title)」の\(timeTypeDescription)まであと30分です"
                print("30分前通知をスケジュール: \(notificationTime)")
            } else {
                // 30分前が現在より過去の場合（=今から30分以内に開始）：予定時間ちょうどに「時間です」通知
                notificationTime = baseTime
                notificationMessage = "「\(task.title)」の\(timeTypeDescription)の時間です"
                print("開始時間通知をスケジュール: \(notificationTime)（30分前が過去のため）")
            }
            
            // 通知コンテンツを作成
            let content = UNMutableNotificationContent()
            content.title = "AIオカンからのお知らせ"
            content.body = notificationMessage
            content.sound = .default
            
            // 通知のカスタムデータ
            content.userInfo = [
                "taskId": task.id,
                "type": "scheduledReminder"
            ]
            
            // 通知トリガーの作成
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            // 通知リクエストの作成
            let request = UNNotificationRequest(
                identifier: "task_notification_\(task.id)",
                content: content,
                trigger: trigger
            )
            
            // 通知のスケジュール
            notificationCenter.add(request) { error in
                if let error = error {
                    print("通知のスケジュールに失敗しました: \(error.localizedDescription)")
                } else {
                    print("通知が正常にスケジュールされました")
                }
            }
        } else {
            print("タスクの予定時間も期限も設定されていないか、過去の時間のため通知はスケジュールされません")
        }
    }
    
    // タスクIDに関連する既存の通知をキャンセル
    private func cancelExistingTaskNotifications(for taskId: String) {
        let identifier = "task_notification_\(taskId)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("タスクID: \(taskId) に関連する既存の通知をキャンセルしました")
    }
    
    // すべての保留中の通知を取得
    func getAllPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
} 
