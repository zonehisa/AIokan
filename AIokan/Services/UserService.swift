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
    var cancellables = Set<AnyCancellable>()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.ensureUserProfile(user: user)
            } else {
                self?.currentUserProfile = nil
            }
        }
    }
    
    func fetchUserProfile(userId: String) {
        print("UserService: ユーザープロファイル取得開始: \(userId)")
        
        // バックグラウンドスレッドで実行されていないことを確認
        if !Thread.isMainThread {
            print("警告: fetchUserProfileがバックグラウンドスレッドで呼び出されています")
        }
        
        db.collection(usersCollection).document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("UserService: ユーザープロファイルの取得エラー: \(error.localizedDescription)")
                return
            }
            
            guard let self = self else { return }
            
            // プロファイルが存在しない場合、現在のAuthユーザー情報を取得して作成を試みる
            guard let snapshot = snapshot, snapshot.exists else {
                print("UserService: ユーザープロファイルが存在しません: \(userId)")
                
                // 現在のAuthユーザーを取得してプロファイルを作成
                if let currentUser = Auth.auth().currentUser, currentUser.uid == userId {
                    print("UserService: 現在のユーザーのプロファイルを作成します: \(userId)")
                    self.createUserProfile(user: currentUser)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print("UserService: プロファイル作成失敗: \(error)")
                            }
                        }, receiveValue: { profile in
                            print("UserService: プロファイル作成成功: \(profile.id)")
                            self.currentUserProfile = profile
                        })
                        .store(in: &self.cancellables)
                }
                return
            }
            
            guard let data = snapshot.data() else {
                print("UserService: ユーザープロファイルデータが空です: \(userId)")
                return
            }
            
            print("UserService: ユーザープロファイルデータ取得成功: \(userId)")
            
            // 新しいヘルパーメソッドを使用して直接Firestoreデータを変換
            var firestoreData = data
            firestoreData["id"] = userId // IDはドキュメントIDから取得
            
            // ディスパッチキューをより明示的に制御
            DispatchQueue.global(qos: .userInitiated).async {
                print("UserService: ユーザープロファイル変換処理開始: \(userId)")
                
                if let userProfile = UserProfile.fromFirestoreData(firestoreData) {
                    DispatchQueue.main.async {
                        print("UserService: ユーザープロファイル設定（メインスレッド）: \(userId)")
                        self.currentUserProfile = userProfile
                        print("UserService: 現在のユーザープロファイル更新完了: \(userId)")
                    }
                } else {
                    print("UserService: ユーザープロファイルの変換に失敗: \(userId)")
                }
            }
        }
    }
    
    // 新しいメソッド: ユーザープロファイルの存在を確認し、必要に応じて作成
    func ensureUserProfile(user: User) {
        print("UserService: ユーザープロファイル確認: \(user.uid)")
        
        db.collection(usersCollection).document(user.uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("UserService: ユーザープロファイル確認エラー: \(error)")
                return
            }
            
            // プロファイルが存在する場合は通常の取得処理
            if let snapshot = snapshot, snapshot.exists {
                print("UserService: ユーザープロファイルが存在します: \(user.uid)")
                self.fetchUserProfile(userId: user.uid)
            } else {
                // プロファイルが存在しない場合は新規作成
                print("UserService: ユーザープロファイルが存在しません。作成します: \(user.uid)")
                self.createUserProfile(user: user)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("UserService: プロファイル作成失敗: \(error)")
                        }
                    }, receiveValue: { profile in
                        print("UserService: プロファイル作成成功: \(profile.id)")
                        self.currentUserProfile = profile
                    })
                    .store(in: &self.cancellables)
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
            
            // 新しいヘルパーメソッドを使用してFirestoreデータに直接変換
            let firestoreData = userProfile.toFirestoreData()
            
            self.db.collection(self.usersCollection).document(user.uid).setData(firestoreData) { error in
                if let error = error {
                    print("ユーザープロファイル作成エラー: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                print("ユーザープロファイル作成成功: \(user.uid)")
                promise(.success(userProfile))
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
            
            // 新しいヘルパーメソッドを使用してFirestoreデータに直接変換
            let firestoreData = userProfile.toFirestoreData()
            
            self.db.collection(self.usersCollection).document(userProfile.id).updateData(firestoreData) { error in
                if let error = error {
                    print("ユーザープロファイル更新エラー: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                print("ユーザープロファイル更新成功: \(userProfile.id)")
                promise(.success(userProfile))
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
            } else {
                print("最終ログイン日時の更新成功: \(userId)")
            }
        }
    }
} 
