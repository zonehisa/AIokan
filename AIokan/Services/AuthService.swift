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

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    
    private let userService = UserService()
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            
            if let user = user {
                self?.userService.updateLastLogin(userId: user.uid)
            }
        }
    }
    
    func signIn(email: String, password: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                if let user = authResult?.user {
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
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let user = authResult?.user else {
                    promise(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザー作成エラー"])))
                    return
                }
                
                // ユーザープロファイルを作成
                guard let self = self else { return }
                
                self.userService.createUserProfile(user: user)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("プロファイル作成エラー: \(error.localizedDescription)")
                        }
                    }, receiveValue: { _ in
                        print("ユーザープロファイルが作成されました")
                    })
                    .store(in: &self.cancellables)
                
                promise(.success(user))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func signInWithGoogle() {
        // Googleログイン処理の実装
        // 注: GoogleSignInライブラリが必要です
        // 以下は実装例です：
        /*
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.signIn(with: config, presenting: UIApplication.shared.windows.first?.rootViewController ?? UIViewController()) { [weak self] user, error in
            if let error = error {
                print("Googleログインエラー: \(error.localizedDescription)")
                return
            }
            
            guard let authentication = user?.authentication,
                  let idToken = authentication.idToken else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authentication.accessToken)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebaseログインエラー: \(error.localizedDescription)")
                    return
                }
                
                // ユーザープロファイルを作成または更新
                if let user = authResult?.user {
                    guard let self = self else { return }
                    self.userService.createUserProfile(user: user)
                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                        .store(in: &self.cancellables)
                }
            }
        }
        */
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() {
        // Appleログイン処理の実装
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        // authorizationController.delegate = context.coordinator
        // authorizationController.presentationContextProvider = context.coordinator
        authorizationController.performRequests()
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
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            // Firebase Authの最新API形式に従って修正（非推奨メソッドを修正）
            let credential: OAuthCredential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                accessToken: idTokenString
            )
            
            // Sign in with Firebase.
            Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
                if let error = error {
                    print("Firebase sign in error: \(error.localizedDescription)")
                    return
                }
                
                // ユーザープロファイルを作成または更新
                if let user = authResult?.user {
                    guard let self = self else { return }
                    self.userService.createUserProfile(user: user)
                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                        .store(in: &self.cancellables)
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("サインアウトエラー: \(error.localizedDescription)")
        }
    }
} 
