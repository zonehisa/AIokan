import SwiftUI
import FirebaseAuth
import Combine
import AuthenticationServices
import Foundation

// ViewModelをクラスに変更
class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    
    // AuthServiceの参照
    var authService: AuthService
    
    // Combineの購読を管理
    var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        authService.signIn(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] _ in
                // ログイン成功、認証状態が更新されればContentViewで自動的に画面が切り替わる
                guard let self = self else { return }
                self.isLoading = false
                // 認証状態の更新を確認する
                print("ログイン成功: \(String(describing: Auth.auth().currentUser?.uid))")
            })
            .store(in: &cancellables)
    }
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            authService.handleSignInWithAppleCompletion(authorization: authorization)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

struct LoginView: View {
    // AuthServiceをEnvironmentObjectとして外部から取得
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = LoginViewModel(authService: AuthService())
    
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
                    TextField("メールアドレス", text: $viewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                    
                    SecureField("パスワード", text: $viewModel.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: {
                    viewModel.login()
                }) {
                    if viewModel.isLoading {
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
                .disabled(viewModel.isLoading)
                
                Button(action: {
                    viewModel.authService.signInWithGoogle()
                }) {
                    Text("Googleでログイン")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
                
                SignInWithAppleButton(
                    onRequest: { request in
                        // リクエスト設定
                    },
                    onCompletion: { result in
                        viewModel.handleAppleSignIn(result: result)
                    }
                )
                .frame(height: 50)
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
                
                NavigationLink(destination: SignUpView().environmentObject(authService)) {
                    Text("アカウントをお持ちでない方はこちら")
                        .foregroundColor(.blue)
                        .padding(.top)
                }
            }
            .padding(.horizontal)
            .navigationBarHidden(true)
        }
        .onAppear {
            // EnvironmentObjectから取得したauthServiceをViewModelに渡す
            viewModel.authService = authService
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
