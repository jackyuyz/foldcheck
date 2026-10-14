import SwiftUI
import FoldL10n
import ReportKit

struct VerifyView: View {
    @Environment(\.appLanguage) private var language
    @State private var verificationResult: VerificationResult?
    @State private var isScanning = false
    @State private var showingDocumentPicker = false
    
    enum VerificationResult {
        case valid(envelope: ReportEnvelope)
        case invalid(reason: String)
        case unknownKey(fingerprint: String)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                actionButtons
                
                if let result = verificationResult {
                    resultSection(result)
                }
                
                explanationSection
            }
            .padding()
        }
        .navigationTitle(L10nKey.verifyTitle.text(in: language))
        .sheet(isPresented: $isScanning) {
            // TODO: QR Scanner view
            Text(L10nKey.verifyScan.text(in: language))
        }
        .sheet(isPresented: $showingDocumentPicker) {
            // TODO: Document picker
            Text(L10nKey.verifyImport.text(in: language))
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text(L10nKey.verifyHeadline.text(in: language))
                .font(.title3.bold())
            
            Text(L10nKey.verifySubtitle.text(in: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                isScanning = true
            } label: {
                Label(L10nKey.verifyScan.text(in: language), systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            
            Button {
                showingDocumentPicker = true
            } label: {
                Label(L10nKey.verifyImport.text(in: language), systemImage: "doc.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    @ViewBuilder
    private func resultSection(_ result: VerificationResult) -> some View {
        VStack(spacing: 12) {
            switch result {
            case .valid(let envelope):
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                
                Text(L10nKey.verifyValid.text(in: language))
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: L10nKey.verifyReportID.text(in: language), value: envelope.reportID.uuidString.prefix(8) + "...")
                    InfoRow(label: L10nKey.verifySignedBy.text(in: language), value: L10nKey.verifyThisDevice.text(in: language))
                    if envelope.isDevelopmentBuild {
                        InfoRow(label: L10nKey.verifyDevNote.text(in: language), value: L10nKey.reportDevUnsigned.text(in: language))
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                
            case .invalid(let reason):
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                
                Text(L10nKey.verifyInvalid.text(in: language))
                    .font(.title3.bold())
                    .foregroundStyle(.red)
                
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                
            case .unknownKey(let fingerprint):
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text(L10nKey.verifyUnknownKey.text(in: language))
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10nKey.verifyUnknownExplain.text(in: language))
                        .font(.subheadline)
                    
                    InfoRow(label: L10nKey.verifyFingerprint.text(in: language), value: fingerprint)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.verifyWhat.text(in: language))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                BulletPoint(text: L10nKey.verifyCheckUnmodified.text(in: language))
                BulletPoint(text: L10nKey.verifyCheckInstall.text(in: language))
                BulletPoint(icon: "xmark.circle", color: .red, text: L10nKey.verifyNotGenuine.text(in: language))
                BulletPoint(icon: "xmark.circle", color: .red, text: L10nKey.verifyNotAccuracy.text(in: language))
            }
            .font(.subheadline)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
        }
    }
}

struct BulletPoint: View {
    var icon: String = "checkmark.circle"
    var color: Color = .green
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        VerifyView()
    }
}
