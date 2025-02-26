//
//  SignUpView.swift
//  AIokan
//
//  Created by AI Assistant on 2025/02/26.
//

import SwiftUI
import FirebaseAuth
import Combine
import Foundation

// ViewModelをクラスとして実装
class SignUpViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    
    var authService: AuthService
    
    var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func signUp(completion: @escaping () -> Void) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "パスワードが一致しません"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "パスワードは6文字以上である必要があります"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        authService.signUp(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completionResult in
                guard let self = self else { return }
                self.isLoading = false
                if case .failure(let error) = completionResult {
                    self.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] _ in
                // アカウント作成成功
                guard let self = self else { return }
                self.isLoading = false
                print("ユーザー登録成功: \(String(describing: Auth.auth().currentUser?.uid))")
                
                // 少し遅延させて、Firestoreへのプロファイル作成が完了する時間を確保
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    completion()
                }
            })
            .store(in: &cancellables)
    }
}

struct SignUpView: View {
    // AuthServiceをEnvironmentObjectとして外部から取得
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = SignUpViewModel(authService: AuthService())
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("アカウント作成")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField("メールアドレス", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                
                SecureField("パスワード", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("パスワード（確認）", text: $viewModel.confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                viewModel.signUp {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("アカウント作成")
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(viewModel.isLoading)
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("ログイン画面に戻る")
                    .foregroundColor(.blue)
            }
            .padding(.top)
        }
        .padding()
        .navigationTitle("アカウント作成")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // EnvironmentObjectから取得したauthServiceをViewModelに渡す
            viewModel.authService = authService
        }
    }
}

#Preview {
    NavigationView {
        SignUpView()
    }
} 
