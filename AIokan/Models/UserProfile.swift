//
//  UserProfile.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    var id: String
    var email: String
    var displayName: String?
    var photoURL: String?
    var createdAt: Date
    var lastLoginAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case photoURL
        case createdAt
        case lastLoginAt
    }
    
    init(id: String, email: String, displayName: String? = nil, photoURL: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.createdAt = Date()
        self.lastLoginAt = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        
        // Firestoreから取得したデータの場合
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else if let timeInterval = try? container.decode(TimeInterval.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            createdAt = Date()
        }
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .lastLoginAt) {
            lastLoginAt = timestamp.dateValue()
        } else if let timeInterval = try? container.decode(TimeInterval.self, forKey: .lastLoginAt) {
            lastLoginAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            lastLoginAt = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(photoURL, forKey: .photoURL)
        
        // JSONエンコードの際はタイムスタンプではなくエポック秒を使用
        try container.encode(createdAt.timeIntervalSince1970, forKey: .createdAt)
        try container.encode(lastLoginAt.timeIntervalSince1970, forKey: .lastLoginAt)
    }
    
    // Firestoreへの直接変換用ヘルパーメソッド
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "email": email,
            "displayName": displayName as Any,
            "photoURL": photoURL as Any,
            "createdAt": Timestamp(date: createdAt),
            "lastLoginAt": Timestamp(date: lastLoginAt)
        ]
    }
    
    // Firestoreからのデータを変換するヘルパーメソッド
    static func fromFirestoreData(_ data: [String: Any]) -> UserProfile? {
        guard 
            let id = data["id"] as? String,
            let email = data["email"] as? String
        else {
            return nil
        }
        
        let displayName = data["displayName"] as? String
        let photoURL = data["photoURL"] as? String
        
        var profile = UserProfile(
            id: id,
            email: email,
            displayName: displayName,
            photoURL: photoURL
        )
        
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            profile.createdAt = createdTimestamp.dateValue()
        }
        
        if let lastLoginTimestamp = data["lastLoginAt"] as? Timestamp {
            profile.lastLoginAt = lastLoginTimestamp.dateValue()
        }
        
        return profile
    }
} 
