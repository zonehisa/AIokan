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

struct SignUpView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var authService = AuthService()
    
    // クラスベースの参照型に変更
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("アカウント作成")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField("メールアドレス", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                
                SecureField("パスワード", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("パスワード（確認）", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                signUp()
            }) {
                if isLoading {
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
            .disabled(isLoading)
            
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
    }
    
    private func signUp() {
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
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            }, receiveValue: { _ in
                // アカウント作成成功
                self.isLoading = false
                self.presentationMode.wrappedValue.dismiss()
            })
            .store(in: &cancellables)
    }
}

#Preview {
    NavigationView {
        SignUpView()
    }
} 
