import SwiftUI
import FirebaseAuth
import Combine
import AuthenticationServices
import Foundation

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    @StateObject private var authService = AuthService()
    
    // クラスベースの参照型に変更
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("AIオカン")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let image = UIImage(named: "logo") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 15) {
                    TextField("メールアドレス", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                    
                    SecureField("パスワード", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: {
                    login()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("ログイン")
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
                    authService.signInWithGoogle()
                }) {
                    Text("Googleでログイン")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(isLoading)
                
                SignInWithAppleButton(
                    onRequest: { request in
                        // リクエスト設定
                    },
                    onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                )
                .frame(height: 50)
                .padding(.horizontal)
                .disabled(isLoading)
                
                NavigationLink(destination: SignUpView()) {
                    Text("アカウントをお持ちでない方はこちら")
                        .foregroundColor(.blue)
                        .padding(.top)
                }
            }
            .padding(.horizontal)
            .navigationBarHidden(true)
        }
        .onAppear {
            // 既にログインしているかチェック
            if Auth.auth().currentUser != nil {
                // メイン画面に遷移
            }
        }
    }
    
    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        authService.signIn(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            }, receiveValue: { _ in
                // ログイン成功、メイン画面に遷移
                self.isLoading = false
            })
            .store(in: &cancellables)
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            authService.handleSignInWithAppleCompletion(authorization: authorization)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

struct SignInWithAppleButton: UIViewRepresentable {
    var onRequest: ((ASAuthorizationAppleIDRequest) -> Void)
    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleAppleSignIn), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButton
        
        init(_ parent: SignInWithAppleButton) {
            self.parent = parent
            super.init()
        }
        
        @objc func handleAppleSignIn() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            parent.onRequest(request)
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = scene.windows.first else {
                return UIWindow()
            }
            return window
        }
    }
}

#Preview {
    LoginView()
}
