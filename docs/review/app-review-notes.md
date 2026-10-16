# FoldCheck - App Review notes

Draft to paste into App Store Connect after replacing the submission items listed below.

FoldCheck is a local, guided phone inspection app for iPhone Duo, with screen, touch, camera, audio, sensor and button tests also available on supported ordinary iPhones. It requires no account. Inspection data, notes, reports and imported attachments remain on the user's device; the app has no business backend, analytics or advertising SDKs. Purchases use Apple's StoreKit.

## Review steps

1. Open Home and select Start Inspection, or select a quick touch, screen or hinge test. All applicable tests and their on-screen results are free. Tests may be skipped.
2. On iPhone Duo, close the device for the outer touch grid and unfold it for the inner grid. The inner grid includes a denser crease band. Changing displays pauses a display test; the user confirms before continuing.
3. In a touch-test introduction, enable “Tap individual cells” to use separate physical contacts instead of swiping. The same setting is under Settings > Accessibility. VoiceOver direct-touch guidance is available on the canvas. Visual tests also offer “Skip - needs sighted help”; the reason is saved in the inspection and report.
4. The hinge test records two guided sweeps and a five-second hold. It assesses continuity and consistency, not calibrated absolute-angle accuracy. Missing readings are Unavailable. Ordinary iPhones mark hinge-dependent tests Not applicable. A manual slider is explicitly identified in the result when used.
5. Camera and microphone permissions are requested only when needed. Denial lets the inspection continue as Skipped. Camera captures retain numerical exposure/sharpness metrics, not test photos. The microphone recording is temporary and removed when the test ends. Touch ID is applicable only when the device offers it.
6. Create Report opens the one-time, non-consumable “FoldCheck Reports” purchase (`com.jackyu.foldcheck.reports`). It unlocks PDF export, saved history and comparison, monthly local reminders, and the fold statistics page. Restore Purchases is available in the paywall and Settings. Tests remain free. Free-user inspections are saved locally so they become available after purchase.
7. Open History to inspect a saved result; select Compare and two inspections to see outcome and metric changes. In Settings, reminders ask for notification permission and schedule locally once a month at 10:00 (days after the 28th use the 28th).
8. Settings > Language switches between English, Spanish, French, Japanese, Simplified Chinese and Traditional Chinese. Report Language can match the interface or stay in English. System permission prompts follow the device's language.
9. Verify is free. Importing a generated PDF verifies its embedded signed report data. Scanning the QR verifies the signature of the embedded hash only. The UI lists the signed results for comparison with the visible pages. A signature does not establish device identity, measurement accuracy, an official certification or an authenticated timestamp; this is a user-generated inspection snapshot. The full PDF file is not digitally signed as a PDF document.

## Fold count and privacy limitations

“Folds observed by FoldCheck” counts only closed-to-open cycles observed while the app is in the foreground. It does not claim a lifetime fold count. FoldCheck does not read battery health, battery cycles, IMEI or serial number. It does not claim to physically measure crease depth or issue an Apple/insurer certification.

The app's own features work offline. StoreKit product loading, purchase and restore require Apple's services. A valid per-install signing key is created in the Secure Enclave where available; development fallback reports are clearly labeled.

## Before submission

- Replace `AppLinks.privacy` (`https://example.com/privacy`) and the Help contact (`support@example.com`) with the owner's actual published policy and working support address; update App Store Connect accordingly.
- Configure and submit the non-consumable product in App Store Connect, including intended price, localization and Family Sharing.
- Add the development team and distribution signing/provisioning. Run purchase, restore, refund and Ask to Buy with a development-installed build/Sandbox account; CLI StoreKit tests may skip when storekitd rejects the installation type.
- Complete real-Duo hardware and human accessibility checks in `m7-validation.md`. Check screenshot dimensions/locales against App Store Connect when uploading.
- Use clean release screenshots. The committed review screenshots and PDFs contain labeled synthetic sample data for QA; they are not evidence of real hardware measurements. `-ScreenshotFixtures`, `-FoldMock` and `-UnlockReports` are DEBUG-only. Developer tools are hidden in Release.
