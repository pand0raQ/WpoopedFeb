import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @StateObject private var viewModel = WelcomeViewModel()
    @State private var isExpanded = false
    @State private var buttonPressed = false
    @State private var feedbackGenerator: UINotificationFeedbackGenerator? = nil
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    ZStack {
                        VStack(alignment: .leading, spacing: geometry.size.height * 0.02) {
                            HStack {
                                Image(systemName: "pawprint.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width * 0.12, height: geometry.size.width * 0.12)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            Text(isExpanded ? "Why log in?" : "Welcome to Wpooped")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if !isExpanded {
                                Text("Wpooped is designed to help dog owners keep track of their furry friends' bathroom habits.")
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.64))
                                    .padding(.bottom, 10)
                                
                                Text("Woof! Let's get started!")
                                    .font(.callout)
                                    .foregroundColor(.white)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    WhyLoginRow(icon: "lock.shield", text: "Securely save your dog's information")
                                    WhyLoginRow(icon: "icloud", text: "Sync data across devices")
                                    WhyLoginRow(icon: "bell", text: "Receive timely walk reminders")
                                    WhyLoginRow(icon: "chart.bar", text: "Track your dog's health trends")
                                    WhyLoginRow(icon: "person.2", text: "Share info with family or dog sitters")
                                    WhyLoginRow(icon: "map", text: "Log and view walk routes")
                                }
                                .padding(.bottom, 10)
                            }
                            
                            Button(action: {
                                if isExpanded {
                                    viewModel.signInWithApple()
                                } else {
                                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                        buttonPressed = true
                                        isExpanded.toggle()
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        buttonPressed = false
                                    }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    
                                    feedbackGenerator = UINotificationFeedbackGenerator()
                                    feedbackGenerator?.prepare()
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        feedbackGenerator?.notificationOccurred(.success)
                                        feedbackGenerator = nil
                                    }
                                }
                            }) {
                                HStack {
                                    if isExpanded {
                                        Image(systemName: "applelogo")
                                            .foregroundColor(.black)
                                    }
                                    Text(isExpanded ? "Sign in with Apple" : "Get started")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(isExpanded ? .black : Color(red: 0.24, green: 0.20, blue: 0.27))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isExpanded ? .white : Color(red: 0.98, green: 0.98, blue: 1))
                                .cornerRadius(25)
                                .scaleEffect(buttonPressed ? 0.95 : 1.0)
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, geometry.size.width * 0.05)
                        .padding(.vertical, geometry.size.height * 0.03)
                    }
                    .frame(width: min(geometry.size.width * 0.9, 910))
                    .frame(minHeight: geometry.size.height * 0.33)
                    .background(Color(red: 0.21, green: 0.18, blue: 0.25))
                    .cornerRadius(35.54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 35.54)
                            .inset(by: 0.5)
                            .stroke(Color(red: 0.08, green: 0.06, blue: 0.09), lineWidth: 0.5)
                    )
                    .shadow(color: Color(red: 0.09, green: 0.10, blue: 0.12, opacity: 0.07), radius: 1)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: isExpanded)
                    Spacer()
                }
                
                Spacer()
                    .frame(height: geometry.safeAreaInsets.bottom + 30)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(Color(red: 0.98, green: 0.98, blue: 1))
        .onDisappear {
            viewModel.getStarted()
        }
    }
}

struct WhyLoginRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.64))
        }
    }
}
