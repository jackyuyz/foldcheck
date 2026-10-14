import SwiftUI
import ReportKit

struct VerifyView: View {
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
        .navigationTitle("Verify Report")
        .sheet(isPresented: $isScanning) {
            // TODO: QR Scanner view
            Text("QR Scanner")
        }
        .sheet(isPresented: $showingDocumentPicker) {
            // TODO: Document picker
            Text("Document Picker")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Verify a FoldCheck Report")
                .font(.title3.bold())
            
            Text("Scan the QR code or import a PDF to verify its authenticity")
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
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            
            Button {
                showingDocumentPicker = true
            } label: {
                Label("Import PDF", systemImage: "doc.fill")
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
                
                Text("Valid Report")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Report ID", value: envelope.reportID.uuidString.prefix(8) + "...")
                    InfoRow(label: "Signed by", value: "This device")
                    if envelope.isDevelopmentBuild {
                        InfoRow(label: "Note", value: "Development build")
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                
            case .invalid(let reason):
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                
                Text("Invalid Report")
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
                
                Text("Valid Signature, Unknown Key")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("This report was signed by a different FoldCheck installation.")
                        .font(.subheadline)
                    
                    InfoRow(label: "Key Fingerprint", value: fingerprint)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What does this verify?")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                BulletPoint(text: "The PDF hasn't been modified since creation")
                BulletPoint(text: "The report was created by a specific FoldCheck installation")
                BulletPoint(icon: "xmark.circle", color: .red, text: "Does NOT verify device authenticity")
                BulletPoint(icon: "xmark.circle", color: .red, text: "Does NOT verify test accuracy")
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
