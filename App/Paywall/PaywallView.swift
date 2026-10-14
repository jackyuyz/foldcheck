import SwiftUI
import FoldL10n

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
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
            .navigationTitle(L10nKey.paywallTitle.text(in: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.paywallClose.text(in: language)) {
                        dismiss()
                    }
                }
            }
            .alert(L10nKey.paywallError.text(in: language), isPresented: .constant(errorMessage != nil)) {
                Button(L10nKey.paywallOk.text(in: language)) {
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
            
            Text(L10nKey.paywallHeadline.text(in: language))
                .font(.title2.bold())
            
            Text(L10nKey.paywallSubtitle.text(in: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(
                icon: "doc.richtext",
                title: L10nKey.paywallPdfTitle.text(in: language),
                description: L10nKey.paywallPdfDetail.text(in: language)
            )
            
            FeatureRow(
                icon: "signature",
                title: L10nKey.paywallSignTitle.text(in: language),
                description: L10nKey.paywallSignDetail.text(in: language)
            )
            
            FeatureRow(
                icon: "qrcode",
                title: L10nKey.paywallQrTitle.text(in: language),
                description: L10nKey.paywallQrDetail.text(in: language)
            )
            
            FeatureRow(
                icon: "clock.arrow.circlepath",
                title: L10nKey.paywallHistoryTitle.text(in: language),
                description: L10nKey.paywallHistoryDetail.text(in: language)
            )
            
            FeatureRow(
                icon: "bell.badge",
                title: L10nKey.paywallReminderTitle.text(in: language),
                description: L10nKey.paywallReminderDetail.text(in: language)
            )
            
            FeatureRow(
                icon: "chart.bar.fill",
                title: L10nKey.paywallStatsTitle.text(in: language),
                description: L10nKey.paywallStatsDetail.text(in: language)
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
                
                Text(L10nKey.paywallOneTime.text(in: language))
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
                    Text(L10nKey.paywallPurchase.text(in: language))
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
                    Text(L10nKey.paywallRestore.text(in: language))
                }
            }
            .font(.subheadline)
            .disabled(isPurchasing || isRestoring)
        }
    }
    
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text(L10nKey.paywallLegal.text(in: language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button(L10nKey.paywallTerms.text(in: language)) {
                    // TODO: Open terms
                }
                Button(L10nKey.paywallPrivacy.text(in: language)) {
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
