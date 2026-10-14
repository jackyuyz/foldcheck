import SwiftUI

struct SettingsView: View {
    @AppStorage("monthlyReminders") private var monthlyReminders = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    
    var body: some View {
        List {
            Section("Notifications") {
                Toggle("Monthly Check-up Reminders", isOn: $monthlyReminders)
            }
            
            Section("Preferences") {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }
            
            Section("Purchases") {
                Button("Restore Purchases") {
                    // TODO: AppStore.sync()
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                NavigationLink("Help & FAQ") {
                    HelpView()
                }
                
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            }
            
            Section {
                NavigationLink("Debug Info") {
                    DebugInfoView()
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("FoldCheck is not affiliated with Apple Inc. This app cannot access battery health, serial numbers, or lifetime fold counts.")
            }
        }
        .navigationTitle("Settings")
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Frequently Asked Questions") {
                FAQItem(
                    question: "Why can't FoldCheck read battery health?",
                    answer: "Apple does not provide battery health data to third-party apps. Only Settings > Battery can show this information."
                )
                
                FAQItem(
                    question: "Is the fold counter accurate?",
                    answer: "The fold counter only tracks folds while FoldCheck is running in the foreground. Apple doesn't expose a lifetime fold count to apps."
                )
                
                FAQItem(
                    question: "What does the digital signature prove?",
                    answer: "It proves the PDF hasn't been edited after creation by that specific FoldCheck installation. It does NOT prove device authenticity."
                )
                
                FAQItem(
                    question: "Why does the hinge test show 'Attention'?",
                    answer: "The hinge test checks for smooth, continuous angle readings. Gaps or inconsistencies may indicate sensor issues, but could also be normal variation."
                )
                
                FAQItem(
                    question: "Can I verify a report from another device?",
                    answer: "Yes! The signature will show as 'Unknown Key' but will still verify the PDF wasn't modified. Each FoldCheck installation has its own signing key."
                )
            }
            
            Section("Contact") {
                Link("Email Support", destination: URL(string: "mailto:support@example.com")!)
            }
        }
        .navigationTitle("Help")
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(question)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DebugInfoView: View {
    var body: some View {
        List {
            Section("Device") {
                HStack {
                    Text("Model")
                    Spacer()
                    Text("Unknown")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("iOS Version")
                    Spacer()
                    Text("Unknown")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Has Hinge")
                    Spacer()
                    Text("Unknown")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Signing Key") {
                HStack {
                    Text("Key Type")
                    Spacer()
                    Text("Software (Dev)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Fingerprint")
                    Spacer()
                    Text("abc12345")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Storage") {
                HStack {
                    Text("Sessions")
                    Spacer()
                    Text("0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Reports")
                    Spacer()
                    Text("0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Debug Info")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
