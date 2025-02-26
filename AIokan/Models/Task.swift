//
//  Task.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import Foundation
import FirebaseFirestore

enum TaskStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .pending:
            return "未着手"
        case .inProgress:
            return "進行中"
        case .completed:
            return "完了"
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high:
            return "高"
        case .medium:
            return "中"
        case .low:
            return "低"
        }
    }
    
    var color: String {
        switch self {
        case .high:
            return "red"
        case .medium:
            return "orange"
        case .low:
            return "blue"
        }
    }
}

enum ReminderType: String, Codable, CaseIterable {
    case urgent = "urgent"
    case normal = "normal"
    case gentle = "gentle"
    
    var displayName: String {
        switch self {
        case .urgent:
            return "厳しい"
        case .normal:
            return "普通"
        case .gentle:
            return "やさしい"
        }
    }
}

struct Task: Identifiable, Codable {
    var id: String
    var title: String
    var description: String?
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var status: TaskStatus
    var priority: TaskPriority
    var notificationTime: Date?
    var reminderType: ReminderType
    var estimatedTime: Int? // 分単位
    var recurrenceRule: String?
    var categoryId: String?
    var tags: [String]
    var parentTaskId: String?
    var progress: Double // 0.0〜1.0
    var calendarEventId: String?
    var location: String?
    var attachments: [String]?
    var userId: String // タスクの所有者
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dueDate: Date? = nil,
        status: TaskStatus = .pending,
        priority: TaskPriority = .medium,
        notificationTime: Date? = nil,
        reminderType: ReminderType = .normal,
        estimatedTime: Int? = nil,
        recurrenceRule: String? = nil,
        categoryId: String? = nil,
        tags: [String] = [],
        parentTaskId: String? = nil,
        progress: Double = 0.0,
        calendarEventId: String? = nil,
        location: String? = nil,
        attachments: [String]? = nil,
        userId: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueDate = dueDate
        self.status = status
        self.priority = priority
        self.notificationTime = notificationTime
        self.reminderType = reminderType
        self.estimatedTime = estimatedTime
        self.recurrenceRule = recurrenceRule
        self.categoryId = categoryId
        self.tags = tags
        self.parentTaskId = parentTaskId
        self.progress = progress
        self.calendarEventId = calendarEventId
        self.location = location
        self.attachments = attachments
        self.userId = userId
    }
    
    // Firestoreからのデータを変換するヘルパーメソッド
    static func fromFirestore(_ data: [String: Any]) -> Task? {
        guard
            let id = data["id"] as? String,
            let title = data["title"] as? String,
            let userId = data["userId"] as? String,
            let statusRaw = data["status"] as? String,
            let status = TaskStatus(rawValue: statusRaw),
            let priorityRaw = data["priority"] as? String,
            let priority = TaskPriority(rawValue: priorityRaw),
            let reminderTypeRaw = data["reminderType"] as? String,
            let reminderType = ReminderType(rawValue: reminderTypeRaw),
            let progress = data["progress"] as? Double
        else {
            return nil
        }
        
        let description = data["description"] as? String
        
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = Date()
        }
        
        let dueDate: Date?
        if let timestamp = data["dueDate"] as? Timestamp {
            dueDate = timestamp.dateValue()
        } else {
            dueDate = nil
        }
        
        let notificationTime: Date?
        if let timestamp = data["notificationTime"] as? Timestamp {
            notificationTime = timestamp.dateValue()
        } else {
            notificationTime = nil
        }
        
        let estimatedTime = data["estimatedTime"] as? Int
        let recurrenceRule = data["recurrenceRule"] as? String
        let categoryId = data["categoryId"] as? String
        let tags = data["tags"] as? [String] ?? []
        let parentTaskId = data["parentTaskId"] as? String
        let calendarEventId = data["calendarEventId"] as? String
        let location = data["location"] as? String
        let attachments = data["attachments"] as? [String]
        
        return Task(
            id: id,
            title: title,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            dueDate: dueDate,
            status: status,
            priority: priority,
            notificationTime: notificationTime,
            reminderType: reminderType,
            estimatedTime: estimatedTime,
            recurrenceRule: recurrenceRule,
            categoryId: categoryId,
            tags: tags,
            parentTaskId: parentTaskId,
            progress: progress,
            calendarEventId: calendarEventId,
            location: location,
            attachments: attachments,
            userId: userId
        )
    }
    
    // Firestoreへのデータ変換用メソッド
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "title": title,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "status": status.rawValue,
            "priority": priority.rawValue,
            "reminderType": reminderType.rawValue,
            "progress": progress,
            "tags": tags,
            "userId": userId
        ]
        
        if let description = description {
            data["description"] = description
        }
        
        if let dueDate = dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        }
        
        if let notificationTime = notificationTime {
            data["notificationTime"] = Timestamp(date: notificationTime)
        }
        
        if let estimatedTime = estimatedTime {
            data["estimatedTime"] = estimatedTime
        }
        
        if let recurrenceRule = recurrenceRule {
            data["recurrenceRule"] = recurrenceRule
        }
        
        if let categoryId = categoryId {
            data["categoryId"] = categoryId
        }
        
        if let parentTaskId = parentTaskId {
            data["parentTaskId"] = parentTaskId
        }
        
        if let calendarEventId = calendarEventId {
            data["calendarEventId"] = calendarEventId
        }
        
        if let location = location {
            data["location"] = location
        }
        
        if let attachments = attachments {
            data["attachments"] = attachments
        }
        
        return data
    }
} 
