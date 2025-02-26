import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AIオカン")
                .font(.largeTitle)
                .fontWeight(.bold)
            Image("logo.png")
                .resizable()
                .frame(width: 150, height: 150)
            
            VStack(spacing: 15) {
                TextField("メールアドレス", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                SecureField("パスワード", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            Button(action: {
                // ログイン処理
            }) {
                Text("ログイン")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            
            Button(action: {
                // Googleログイン処理
            }) {
                Text("Googleでログイン")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button(action: {
                // Appleログイン処理
            }) {
                Text("Appleでログイン")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
        
    }
}

#Preview {
    LoginView()
}
