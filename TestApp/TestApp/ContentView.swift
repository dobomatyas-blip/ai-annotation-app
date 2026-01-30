import SwiftUI
import SwiftAnnotation

struct ContentView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Login Tab
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Logo
                    Image(systemName: "ear.badge.waveform")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                        .accessibilityIdentifier("appLogo")
                        .accessibilityLabel("App Logo")

                    Text("Welcome to Ear")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityIdentifier("welcomeTitle")
                        .accessibilityLabel("Welcome to Ear")

                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Login Form
                    VStack(spacing: 16) {
                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("usernameField")

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("passwordField")

                        Toggle("Remember me", isOn: $rememberMe)
                            .accessibilityIdentifier("rememberMeToggle")

                        Button {
                            // Login action
                        } label: {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("signInButton")

                        Button("Forgot Password?") {
                            // Forgot password action
                        }
                        .font(.footnote)
                        .accessibilityIdentifier("forgotPasswordButton")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                    .frame(maxWidth: 400)

                    // Social Login
                    VStack(spacing: 12) {
                        Text("Or continue with")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 20) {
                            SocialButton(icon: "apple.logo", label: "Apple")
                            SocialButton(icon: "globe", label: "Google", backgroundColor: .blue.opacity(0.3))
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(Color.orange.opacity(0.05))
            .tabItem {
                Label("Login", systemImage: "person.circle")
            }
            .tag(0)

            // Settings Tab
            List {
                Section("Account") {
                    SettingsRow(icon: "person.fill", title: "Profile", color: .blue)
                    SettingsRow(icon: "bell.fill", title: "Notifications", color: .red)
                    SettingsRow(icon: "lock.fill", title: "Privacy", color: .green)
                }

                Section("Preferences") {
                    SettingsRow(icon: "paintbrush.fill", title: "Appearance", color: .purple)
                    SettingsRow(icon: "globe", title: "Language", color: .orange)
                    SettingsRow(icon: "speaker.wave.3.fill", title: "Sound", color: .pink)
                }

                Section("Support") {
                    SettingsRow(icon: "questionmark.circle.fill", title: "Help Center", color: .teal)
                    SettingsRow(icon: "envelope.fill", title: "Contact Us", color: .indigo)
                }
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(1)
        }
        .frame(minWidth: 600, minHeight: 500)
        // Add the annotation overlay with a floating button
        .withAnnotationButton()
    }
}

// MARK: - Supporting Views

struct SocialButton: View {
    let icon: String
    let label: String
    var backgroundColor: Color = Color.gray.opacity(0.2)

    var body: some View {
        Button {
            // Social login action
        } label: {
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .frame(width: 120)
            .padding()
            .background(backgroundColor)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(label.lowercased())LoginButton")
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 30)

            Text(title)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("\(title.lowercased().replacingOccurrences(of: " ", with: ""))Row")
    }
}

#Preview {
    ContentView()
}
