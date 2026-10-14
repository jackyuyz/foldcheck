# FoldCheck UI mockups

These drawings are for iPhone Duo postures, not a portrait iPhone. The glass follows `DuoDisplaySpec`: the unfolded inner display is 2670×1878 px (~1.42:1) and the cover is 1398×2034 px (~1:1.455). Bezel is extra. The app opens in English. Settings can switch the interface to Español, Français, 日本語, 简体中文, or 繁體中文.

| File | Posture | Screen |
|---|---|---|
| `png/01-home-unfolded.png` | Fully open, inner display | Home: start inspection on the left, last result and shortcuts on the right, crease in the center |
| `png/02-test-intro-unfolded.png` | Fully open, inner display | Test intro: instructions on the left, diagram on the right, buttons clear of the crease |
| `png/03-hinge-sweep-unfolded.png` | Fully open, inner display | Hinge sweep across both halves: angle on the left, curve on the right |
| `png/04-touch-grid-unfolded.png` | Fully open, inner display | Touch grid across both inner halves, with half-size cells on the crease |
| `png/05-summary-unfolded.png` | Fully open, inner display | Summary: score on the left, results on the right |
| `png/06-report-unfolded.png` | Fully open, inner display | Report: PDF on the left, QR and signature on the right |
| `png/07-verify-unfolded.png` | Fully open, inner display | Verify: scan or import on the left, signature result on the right |
| `png/08-paywall-unfolded.png` | Fully open, inner display | Report unlock: features on the left, price on the right |
| `png/11-settings-language-unfolded.png` | Fully open, inner display | Settings: English selected, with Español, Français, 日本語, 简体中文, and 繁體中文. Report language can match the app or stay English |
| `png/09-crease-partial.png` | Partially open | Two screens split by the hinge; rating on the left, crease pattern on the right |
| `png/10-cover-folded.png` | Closed | Cover display. Hinge thickness is drawn on the right |

Sources live in `render/` and are exported to `png/` with headless Chrome. When fully open the hinge gap is zero, so the drawing keeps only a light crease. The partially open drawing separates the two panels.
