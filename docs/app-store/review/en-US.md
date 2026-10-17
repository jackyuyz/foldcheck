# App Review Notes · English

Review-only draft. Copy the block into App Review Information > Notes after the internal pending items are resolved. This is not public product-page copy. Contact fields and submission build are **TBC / 待确认** in `../internal/TODO.md`; no credentials are fabricated here.

## review-notes

```text
FoldCheck is a local, guided phone inspection app. No app account or login is required. It has no business backend, advertising or analytics SDKs. Inspections, notes and imported attachments stay on the device unless the user shares them. Product loading, purchase and restore use Apple's StoreKit services.

Review steps:
1. From Home, choose Start Inspection or a quick Touch Test, Screen Test or Hinge Check. Applicable tests and on-screen results are free; tests may be skipped. Verify is also free.
2. Hinge and crease features require iPhone Duo with the supported hinge APIs (the implementation is gated to iOS 27.1+). Use a physical compatible device for hardware assessment. Other iPhones can run applicable checks; hinge-dependent items are Not applicable. A simulator or missing hardware may return Unavailable.
3. For Duo touch tests, close the device for the cover and unfold it for the inner screen. The inner screen includes a denser crease band. Rotation keeps the same physical cells and coverage; switching physical displays pauses for confirmation and starts a separate grid.
4. Touch-test introductions and Settings > Accessibility offer individual-cell tapping. It counts physical contact beginnings rather than dragged paths. Visual tests offer a sighted-help skip with its reason recorded. The app also responds to larger text and Reduce Motion preferences.
5. Hinge Check includes two guided sweeps and a five-second hold. It evaluates continuity and consistency, not calibrated angle accuracy. Missing samples are reported as unavailable. If a manual slider is used, the result identifies it.
6. Camera, microphone and QR-scanning access are requested when needed. Camera test frames contribute numerical exposure/sharpness results; photos stay in memory unless the user explicitly attaches them to the report at test completion. Microphone recordings are temporary and removed when the test ends. Crease photos are optionally imported with the system picker. Earpiece testing is offered only when the system can route to its built-in receiver; unavailable routing is not a fault. Permission denial can be skipped. Touch ID applies only to devices that offer it; other button checks include user confirmation.
7. Create Report opens the one-time non-consumable FoldCheck Reports purchase (product ID: com.jackyu.foldcheck.reports). It unlocks PDF export, saved-history access and comparison, monthly local reminders and fold statistics. Restore Purchases is on the paywall and in Settings. Full inspections are saved automatically; quick results have Save to History. Access to history is purchase-gated, even when records were saved before purchase.
8. After unlocking, compare two saved inspections in History. Enable monthly reminders in Settings and allow notifications. Reminders are local. Fold statistics only count closed-to-open cycles observed while the app is foregrounded, not lifetime folds.
9. In Settings, select English, Simplified or Traditional Chinese, Japanese, French or Spanish. Reports follow the interface language or can remain in English.
10. Verify can import a generated PDF or scan its QR code. PDF import checks embedded signed report data; QR scanning checks the signature for its hash. Neither validates every visible PDF page, device identity, measurement accuracy or the device clock. Reports are user-generated inspection records, not official certificates. No battery-health, serial-number, IMEI or physical crease-depth measurement is claimed.

Release does not expose debug fold controls, sample-history fixtures or launch-argument purchase overrides. A missing Secure Enclave uses an explicitly labeled development signer; this is not represented as hardware-backed signing.
```
