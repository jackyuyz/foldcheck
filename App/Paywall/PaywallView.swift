import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    featuresSection
                    
                    purchaseSection
                    
                    termsSection
                }
                .padding()
            }
            .navigationTitle("FoldCheck Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Unlock PDF Reports")
                .font(.title2.bold())
            
            Text("Create professional inspection reports with tamper-evident signatures")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(
                icon: "doc.richtext",
                title: "PDF Reports",
                description: "Generate detailed reports with all test results and charts"
            )
            
            FeatureRow(
                icon: "signature",
                title: "Digital Signature",
                description: "Tamper-evident signing using your device's Secure Enclave"
            )
            
            FeatureRow(
                icon: "qrcode",
                title: "QR Verification",
                description: "Each report includes a QR code for instant verification"
            )
            
            FeatureRow(
                icon: "clock.arrow.circlepath",
                title: "History & Compare",
                description: "Track changes over time and compare inspections"
            )
            
            FeatureRow(
                icon: "bell.badge",
                title: "Monthly Reminders",
                description: "Get notified to run regular check-ups"
            )
            
            FeatureRow(
                icon: "chart.bar.fill",
                title: "Fold Statistics",
                description: "View detailed fold counter stats per session"
            )
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("$2.99")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                Text("One-time purchase")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                purchase()
            } label: {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Purchase")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.tint, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .disabled(isPurchasing || isRestoring)
            
            Button {
                restore()
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                }
            }
            .font(.subheadline)
            .disabled(isPurchasing || isRestoring)
        }
    }
    
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("All tests are always free. PDF reports, history, and comparison features require this one-time purchase.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Terms of Service") {
                    // TODO: Open terms
                }
                Button("Privacy Policy") {
                    // TODO: Open privacy
                }
            }
            .font(.caption)
        }
    }
    
    private func purchase() {
        isPurchasing = true
        // TODO: Implement StoreKit 2 purchase
        // For now, simulate a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isPurchasing = false
            // dismiss()
        }
    }
    
    private func restore() {
        isRestoring = true
        // TODO: Implement AppStore.sync()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRestoring = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView()
}
