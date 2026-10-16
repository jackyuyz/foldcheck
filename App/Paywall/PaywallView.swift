import SwiftUI
import FoldL10n
import Store

/// S9: the one-time "FoldCheck Reports" unlock. Shows the App Store price, handles pending
/// approval (Ask to Buy) and restore, and closes on its own once the purchase is unlocked.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @Environment(Store.self) private var store
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
                    .accessibilityIdentifier("paywall.close")
                }
            }
            .onChange(of: store.hasReports, initial: true) { _, unlocked in
                if unlocked { dismiss() }
            }
            .onChange(of: store.purchaseState) { _, state in
                if state == .failed { errorMessage = L10nKey.paywallFailed.text(in: language) }
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
            switch store.loadState {
            case .loading:
                ProgressView()
                    .accessibilityIdentifier("paywall.loading")
            case .unavailable:
                VStack(spacing: 8) {
                    Text(L10nKey.paywallUnavailable.text(in: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L10nKey.paywallRetry.text(in: language)) {
                        Task { await store.loadProduct() }
                    }
                }
                .accessibilityIdentifier("paywall.unavailable")
            case .loaded:
                if let product = store.product {
                    VStack(spacing: 4) {
                        // The App Store's localized price; never hardcoded.
                        Text(product.displayPrice)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .accessibilityIdentifier("paywall.price")
                        Text(L10nKey.paywallOneTime.text(in: language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if store.purchaseState == .pending {
                Label(L10nKey.paywallPending.text(in: language), systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("paywall.pending")
            }

            Button {
                Task { await store.purchase() }
            } label: {
                if store.purchaseState == .purchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(L10nKey.paywallPurchase.text(in: language))
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(InspectionStyle.buttonFill, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .disabled(store.product == nil || store.purchaseState == .purchasing || isRestoring)
            .accessibilityIdentifier("paywall.purchase")

            Button {
                Task { await restore() }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text(L10nKey.paywallRestore.text(in: language))
                }
            }
            .font(.subheadline)
            .disabled(store.purchaseState == .purchasing || isRestoring)
            .accessibilityIdentifier("paywall.restore")
        }
    }

    private var termsSection: some View {
        VStack(spacing: 8) {
            Text(L10nKey.paywallLegal.text(in: language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link(L10nKey.paywallTerms.text(in: language), destination: AppLinks.terms)
                Link(L10nKey.paywallPrivacy.text(in: language), destination: AppLinks.privacy)
            }
            .font(.caption)
        }
    }

    private func restore() async {
        isRestoring = true
        let unlocked = await store.restore()
        isRestoring = false
        if !unlocked {
            errorMessage = L10nKey.paywallNothingToRestore.text(in: language)
        }
    }
}

/// Links shown on the paywall and in Settings.
enum AppLinks {
    /// Apple's standard license agreement, which covers a non-consumable purchase.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    // TODO(before submission): the real privacy policy page ("FoldCheck collects no data").
    static let privacy = URL(string: "https://example.com/privacy")!
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
        .environment(Store())
}
