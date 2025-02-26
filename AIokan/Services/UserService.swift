//
//  UserService.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class UserService: ObservableObject {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    @Published var currentUserProfile: UserProfile?
    private var cancellables = Set<AnyCancellable>()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.fetchUserProfile(userId: user.uid)
            } else {
                self?.currentUserProfile = nil
            }
        }
    }
    
    func fetchUserProfile(userId: String) {
        db.collection(usersCollection).document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("ユーザープロファイルの取得エラー: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                print("ユーザープロファイルが存在しません")
                return
            }
            
            do {
                let data = snapshot.data() ?? [:]
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let userProfile = try JSONDecoder().decode(UserProfile.self, from: jsonData)
                
                DispatchQueue.main.async {
                    self?.currentUserProfile = userProfile
                }
            } catch {
                print("ユーザープロファイルのデコードエラー: \(error.localizedDescription)")
            }
        }
    }
    
    func createUserProfile(user: User) -> AnyPublisher<UserProfile, Error> {
        return Future<UserProfile, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            let userProfile = UserProfile(
                id: user.uid,
                email: user.email ?? "",
                displayName: user.displayName,
                photoURL: user.photoURL?.absoluteString
            )
            
            do {
                let data = try JSONEncoder().encode(userProfile)
                let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                self.db.collection(self.usersCollection).document(user.uid).setData(dict) { error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    promise(.success(userProfile))
                }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateUserProfile(userProfile: UserProfile) -> AnyPublisher<UserProfile, Error> {
        return Future<UserProfile, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "サービスが利用できません"])))
                return
            }
            
            do {
                let data = try JSONEncoder().encode(userProfile)
                let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                self.db.collection(self.usersCollection).document(userProfile.id).updateData(dict) { error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    promise(.success(userProfile))
                }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateLastLogin(userId: String) {
        let data: [String: Any] = [
            "lastLoginAt": Timestamp(date: Date())
        ]
        
        db.collection(usersCollection).document(userId).updateData(data) { error in
            if let error = error {
                print("最終ログイン日時の更新エラー: \(error.localizedDescription)")
            }
        }
    }
} 
