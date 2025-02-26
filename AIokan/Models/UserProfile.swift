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
        
        let createdAtTimestamp = try container.decode(Timestamp.self, forKey: .createdAt)
        createdAt = createdAtTimestamp.dateValue()
        
        let lastLoginAtTimestamp = try container.decode(Timestamp.self, forKey: .lastLoginAt)
        lastLoginAt = lastLoginAtTimestamp.dateValue()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(photoURL, forKey: .photoURL)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(Timestamp(date: lastLoginAt), forKey: .lastLoginAt)
    }
} 
