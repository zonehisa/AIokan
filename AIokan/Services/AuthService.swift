//
//  AuthService.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import Foundation
import FirebaseAuth
import Combine
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift
import FirebaseCore
import UIKit
import SwiftUI

// ConfigurationManagerはすでに同じモジュール内にあるので明示的なインポートは不要

// プレゼンテーションコンテキストプロバイダークラス
class AppleAuthorizationPresentation: NSObject, ASAuthorizationControllerPresentationContextProviding {
    private var window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
        super.init()
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return window
    }
}

class AuthService: NSObject, ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    
    private let userService = UserService()
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    override init() {
        super.init()
        
        // デバッグログ
        print("AuthService: 初期化開始")
        
        // 初期状態を設定
        let currentUser = Auth.auth().currentUser
        self.user = currentUser
        self.isAuthenticated = currentUser != nil
        
        print("AuthService初期化: 現在のユーザー = \(currentUser?.uid ?? "なし"), isAuthenticated = \(isAuthenticated)")
        
        // ユーザーがすでにログインしている場合、プロファイルを確認・作成
        if let currentUser = currentUser {
            print("AuthService: 現在のユーザーのプロファイルを確認します: \(currentUser.uid)")
            self.userService.ensureUserProfile(user: currentUser)
        }
        
        // Firebaseの認証状態変更リスナーを設定
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else {
                print("警告: AuthStateListener - selfが解放されています")
                return
            }
            
            print("認証状態変更検出: userID = \(user?.uid ?? "なし")")
            
            // UI更新は必ずメインスレッドで行う
            DispatchQueue.main.async {
                // 前の状態と現在の状態をログ出力
                let oldAuthenticated = self.isAuthenticated
                let newAuthenticated = user != nil
                
                // 状態を更新
                self.user = user
                self.isAuthenticated = newAuthenticated
                
                print("認証状態変更: \(oldAuthenticated) -> \(newAuthenticated), userId = \(user?.uid ?? "なし")")
                
                if let user = user {
                    // 最終ログイン日時を更新
                    self.userService.updateLastLogin(userId: user.uid)
                    
                    // ユーザープロファイルを確認・作成
                    print("AuthStateListener: ユーザープロファイルを確認します: \(user.uid)")
                    self.userService.ensureUserProfile(user: user)
                }
            }
        }
    }
    
    func signIn(email: String, password: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                if let user = authResult?.user {
                    // 認証状態を明示的に更新
                    DispatchQueue.main.async {
                        self?.user = user
                        self?.isAuthenticated = true
                        print("signIn - 認証状態を明示的に更新: user=\(user.uid)")
                    }
                    promise(.success(user))
                } else {
                    promise(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "不明なエラーが発生しました"])))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func signUp(email: String, password: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            print("AuthService: ユーザー登録開始 - \(email)")
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("AuthService: ユーザー登録エラー - \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                guard let user = authResult?.user else {
                    print("AuthService: ユーザー登録失敗 - ユーザーが取得できませんでした")
                    promise(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザー作成エラー"])))
                    return
                }
                
                print("AuthService: ユーザー登録成功 - \(user.uid)")
                
                // 認証状態を明示的に更新
                DispatchQueue.main.async {
                    self?.user = user
                    self?.isAuthenticated = true
                    print("signUp - 認証状態を明示的に更新: user=\(user.uid), isAuthenticated=true")
                }
                
                // ユーザープロファイルを作成
                guard let self = self else {
                    // selfが解放されていてもユーザー作成自体は成功しているので、成功として扱う
                    print("AuthService: self解放のためプロファイル作成をスキップ")
                    promise(.success(user))
                    return
                }
                
                print("AuthService: ユーザープロファイル作成開始 - \(user.uid)")
                self.userService.createUserProfile(user: user)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("AuthService: プロファイル作成エラー - \(error.localizedDescription)")
                            // プロファイル作成失敗でもユーザー作成自体は成功しているので、成功として扱う
                        } else {
                            print("AuthService: プロファイル作成完了 - \(user.uid)")
                        }
                        // 完了通知をここで送る（エラーがあっても）
                        promise(.success(user))
                    }, receiveValue: { _ in
                        print("AuthService: ユーザープロファイルが作成されました - \(user.uid)")
                        // 成功値を受信した時点では完了通知を送らない（receiveCompletionで送る）
                    })
                    .store(in: &self.cancellables)
            }
        }
        .eraseToAnyPublisher()
    }
    
    func signInWithGoogle() {
        // メインスレッドで実行することを確認
        if !Thread.isMainThread {
            print("警告: signInWithGoogleがメインスレッド以外で呼び出されています")
            DispatchQueue.main.async {
                self.signInWithGoogle()
            }
            return
        }
        
        print("Google認証開始")
        
        // ルートビューコントローラーの取得方法を改善
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("ルートビューコントローラーが見つかりません")
            return
        }
        
        print("ルートビューコントローラー取得成功: \(type(of: rootViewController))")
        
        // GoogleSignIn設定の詳細をログ出力
        if let config = GIDSignIn.sharedInstance.configuration {
            print("GoogleSignIn設定: クライアントID = \(config.clientID)")
        } else {
            print("警告: GoogleSignInの設定がありません")
        }
        
        // GoogleSignInの現在のAPIに合わせて修正 - シンプル化
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            if let error = error {
                print("Googleログインエラー: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("エラー詳細: \(nsError.domain), コード: \(nsError.code), 説明: \(nsError.userInfo)")
                }
                return
            }
            
            guard let result = result else {
                print("認証情報の取得に失敗しました")
                return
            }
            
            guard let idToken = result.user.idToken?.tokenString else {
                print("IDトークンの取得に失敗しました")
                return
            }
            
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            print("Firebase認証開始: IDトークンとアクセストークンを取得しました")
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    print("Firebaseログインエラー: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("Firebase詳細エラー: \(nsError.domain), コード: \(nsError.code), 説明: \(nsError.userInfo)")
                    }
                    return
                }
                
                // ユーザープロファイルを作成または更新
                if let user = authResult?.user {
                    print("Firebase認証成功: ユーザーID \(user.uid)")
                    guard let self = self else { return }
                    self.userService.createUserProfile(user: user)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print("プロファイル作成エラー: \(error.localizedDescription)")
                            }
                        }, receiveValue: { _ in
                            print("Googleログイン成功：ユーザープロファイルを更新しました")
                        })
                        .store(in: &self.cancellables)
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() {
        // 開発用のモック実装
        print("Apple Sign Inはモック実装中です（Apple Developer Programの登録が必要）")
        
        // メインスレッドであることを確認
        if !Thread.isMainThread {
            print("警告: signInWithAppleがメインスレッド以外で呼び出されています")
            DispatchQueue.main.async {
                self.signInWithApple()
            }
            return
        }
        
        // モック認証のためのダミーユーザー作成
        let mockUser = Auth.auth().currentUser
        if mockUser == nil {
            // すでにログインしていなければ、匿名ログインを行う
            print("モック認証: 匿名ログインを開始します")
            Auth.auth().signInAnonymously { [weak self] (authResult, error) in
                if let error = error {
                    print("モック認証エラー: \(error.localizedDescription)")
                    return
                }
                
                guard let user = authResult?.user else {
                    print("モック認証: ユーザーが取得できませんでした")
                    return
                }
                print("モック認証成功: \(user.uid)")
                
                // 認証状態を明示的に更新（メインスレッドでUIを更新）
                DispatchQueue.main.async {
                    self?.user = user
                    self?.isAuthenticated = true
                    print("モック認証: 認証状態を更新しました - isAuthenticated = \(self?.isAuthenticated ?? false)")
                }
                
                // ユーザープロファイルを作成
                guard let self = self else {
                    print("モック認証: selfが解放されました")
                    return
                }
                self.userService.createUserProfile(user: user)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("プロファイル作成エラー: \(error.localizedDescription)")
                        } else {
                            print("モックユーザープロファイル作成完了")
                        }
                    }, receiveValue: { _ in
                        print("モックユーザープロファイルが作成されました")
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            print("すでにログインしています: \(mockUser!.uid)")
            // 認証状態を明示的に更新（既存ユーザーの場合）
            DispatchQueue.main.async {
                self.user = mockUser
                self.isAuthenticated = true
                print("モック認証（既存ユーザー）: 認証状態を更新しました - isAuthenticated = \(self.isAuthenticated)")
            }
        }
    }
    
    // Apple Sign In用のヘルパーメソッド
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    func handleSignInWithAppleCompletion(authorization: ASAuthorization) {
        // 開発用のモック実装
        print("handleSignInWithAppleCompletionはモック実装中です（Apple Developer Programの登録が必要）")
        
        // 実際の実装は無効化されていますが、UIフローを維持するためにここで処理を完了させます
        // 必要に応じて、ここでモックユーザーで認証を行うことも可能です
    }
    
    func signOut() {
        print("ログアウト処理開始")
        
        // メインスレッド確認
        if !Thread.isMainThread {
            print("警告: signOutがメインスレッド以外で呼び出されています")
            DispatchQueue.main.async {
                self.signOut()
            }
            return
        }
        
        do {
            // 状態を先に更新してUIの応答性を確保
            self.user = nil
            self.isAuthenticated = false
            print("認証状態を先に更新: isAuthenticated = false")
            
            // 実際のログアウト処理（これがブロックしても上のUI更新は先に実行される）
            try Auth.auth().signOut()
            print("Firebase認証: ログアウト成功")
        } catch {
            print("サインアウトエラー: \(error.localizedDescription)")
            
            // エラーが発生した場合は再度現在の認証状態を確認
            let currentUser = Auth.auth().currentUser
            DispatchQueue.main.async {
                self.user = currentUser
                self.isAuthenticated = currentUser != nil
                print("エラー発生後の状態リセット: isAuthenticated = \(self.isAuthenticated)")
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleSignInWithAppleCompletion(authorization: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign Inエラー: \(error.localizedDescription)")
    }
}
