import SwiftUI
import FoldL10n
import TestsKit

/// S4: the outcome and metrics of the test just run, plus a notes field.
struct TestResultReviewView: View {
    let result: TestResult
    let onContinue: (TestResult) -> Void

    @Environment(\.appLanguage) private var language
    @State private var userNote = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: result.outcome.iconName)
                        .font(.system(size: 56))
                        .foregroundStyle(ResultBadge.color(for: result.outcome))
                    Text(result.outcome.localizedName(in: language))
                        .font(.title.bold())
                        .accessibilityIdentifier("result.outcome")
                    Text(result.id.localizedName(in: language))
                        .font(.headline)
                    if let display = result.display {
                        Text(display.localizedName(in: language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 24)

                let lines = ResultMetricsFormatter.lines(for: result, language: language)
                if !lines.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(lines, id: \.self) { line in
                            HStack {
                                Text(line.label)
                                Spacer()
                                Text(line.value)
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                            if line != lines.last { Divider() }
                        }
                    }
                    .padding(.horizontal)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("result.metrics")
                }

                if !result.notes.isEmpty {
                    Text(result.notes)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("result.systemNotes")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10nKey.resultNotes.text(in: language))
                        .font(.headline)
                    TextField(L10nKey.resultNotesPlaceholder.text(in: language), text: $userNote, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("result.notes")
                }

                Button {
                    var final = result
                    let note = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !note.isEmpty {
                        final.notes = [result.notes, note].filter { !$0.isEmpty }.joined(separator: "\n")
                    }
                    onContinue(final)
                } label: {
                    Text(L10nKey.testContinue.text(in: language))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("result.continue")
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
