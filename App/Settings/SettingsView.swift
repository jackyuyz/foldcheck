import SwiftUI
import FoldL10n
import Store

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Store.self) private var store
    @AppStorage("monthlyReminders") private var monthlyReminders = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @State private var remindersDenied = false
    @State private var showingPaywall = false
    @State private var restoreMessage: String?

    private var language: AppLanguage { settings.appLanguage }

    /// Turning reminders on needs the purchase and notification permission; if either is
    /// missing the toggle stays off.
    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { monthlyReminders },
            set: { isOn in
                guard isOn else {
                    MonthlyReminder.disable()
                    monthlyReminders = false
                    return
                }
                guard store.hasReports else {
                    showingPaywall = true
                    return
                }
                Task {
                    let scheduled = await MonthlyReminder.enable(language: language)
                    monthlyReminders = scheduled
                    remindersDenied = !scheduled
                }
            }
        )
    }

    var body: some View {
        @Bindable var settings = settings
        List {
            Section {
                Picker(L10nKey.settingsLanguage.text(in: language), selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.nativeName).tag(option)
                    }
                }
            } footer: {
                Text(L10nKey.settingsLanguageFooter.text(in: language))
            }

            Section {
                Picker(L10nKey.settingsReportLanguage.text(in: language), selection: $settings.reportUsesEnglish) {
                    Text(L10nKey.settingsReportMatch.text(in: language)).tag(false)
                    Text(L10nKey.settingsReportEnglish.text(in: language)).tag(true)
                }
            } footer: {
                Text(L10nKey.settingsReportFooter.text(in: language))
            }

            Section {
                Toggle(L10nKey.settingsMonthly.text(in: language), isOn: remindersBinding)
                    .accessibilityIdentifier("settings.monthlyReminders")
            } header: {
                Text(L10nKey.settingsNotifications.text(in: language))
            } footer: {
                if remindersDenied {
                    Text(L10nKey.settingsRemindersOff.text(in: language))
                }
            }

            Section(L10nKey.settingsPreferences.text(in: language)) {
                Toggle(L10nKey.settingsHaptics.text(in: language), isOn: $hapticFeedback)
            }

            Section(L10nKey.settingsPurchases.text(in: language)) {
                Button(L10nKey.paywallRestore.text(in: language)) {
                    Task {
                        let unlocked = await store.restore()
                        restoreMessage = unlocked
                            ? L10nKey.paywallRestored.text(in: language)
                            : L10nKey.paywallNothingToRestore.text(in: language)
                    }
                }
                .accessibilityIdentifier("settings.restore")
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10nKey.settingsAbout.text(in: language)) {
                HStack {
                    Text(L10nKey.settingsVersion.text(in: language))
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                NavigationLink(L10nKey.settingsHelp.text(in: language)) {
                    HelpView()
                }

                Link(L10nKey.paywallPrivacy.text(in: language), destination: AppLinks.privacy)

                Link(L10nKey.paywallTerms.text(in: language), destination: AppLinks.terms)
            }

            Section {
                NavigationLink(L10nKey.settingsDebug.text(in: language)) {
                    DebugInfoView()
                }
            } header: {
                Text(L10nKey.settingsDeveloper.text(in: language))
            } footer: {
                Text(L10nKey.settingsFooter.text(in: language))
            }
        }
        .navigationTitle(L10nKey.settingsTitle.text(in: language))
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .onChange(of: store.hasReports) { _, unlocked in
            // A refund takes reminders away with the rest of the purchase.
            if !unlocked && monthlyReminders {
                MonthlyReminder.disable()
                monthlyReminders = false
            }
        }
    }
}

struct HelpView: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        List {
            Section(L10nKey.settingsFaq.text(in: language)) {
                FAQItem(
                    question: L10nKey.faqBatteryQ.text(in: language),
                    answer: L10nKey.faqBatteryA.text(in: language)
                )

                FAQItem(
                    question: L10nKey.faqFoldsQ.text(in: language),
                    answer: L10nKey.faqFoldsA.text(in: language)
                )

                FAQItem(
                    question: L10nKey.faqSignatureQ.text(in: language),
                    answer: L10nKey.faqSignatureA.text(in: language)
                )

                FAQItem(
                    question: L10nKey.faqHingeQ.text(in: language),
                    answer: L10nKey.faqHingeA.text(in: language)
                )

                FAQItem(
                    question: L10nKey.faqOtherDeviceQ.text(in: language),
                    answer: L10nKey.faqOtherDeviceA.text(in: language)
                )
            }

            Section(L10nKey.settingsContact.text(in: language)) {
                Link(L10nKey.settingsEmail.text(in: language), destination: URL(string: "mailto:support@example.com")!)
            }
        }
        .navigationTitle(L10nKey.settingsHelp.text(in: language))
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
    @Environment(\.appLanguage) private var language

    var body: some View {
        List {
            Section(L10nKey.debugDevice.text(in: language)) {
                HStack {
                    Text(L10nKey.debugModel.text(in: language))
                    Spacer()
                    Text(L10nKey.debugUnknown.text(in: language))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10nKey.debugIos.text(in: language))
                    Spacer()
                    Text(L10nKey.debugUnknown.text(in: language))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10nKey.debugHinge.text(in: language))
                    Spacer()
                    Text(L10nKey.debugUnknown.text(in: language))
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10nKey.debugSigning.text(in: language)) {
                HStack {
                    Text(L10nKey.debugKeyType.text(in: language))
                    Spacer()
                    Text(L10nKey.debugSoftware.text(in: language))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10nKey.debugFingerprint.text(in: language))
                    Spacer()
                    Text("abc12345")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10nKey.debugStorage.text(in: language)) {
                HStack {
                    Text(L10nKey.debugSessions.text(in: language))
                    Spacer()
                    Text("0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10nKey.debugReports.text(in: language))
                    Spacer()
                    Text("0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(L10nKey.debugTitle.text(in: language))
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppSettings())
    .environment(Store())
    .environment(\.appLanguage, AppLanguage.en)
}
