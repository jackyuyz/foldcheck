# FoldCheck UI Mockups

This directory contains UI mockups for the FoldCheck app covering key screens on both inner (unfolded) and outer (cover) displays.

## Viewing the Mockups

The mockups are provided in two formats:

1. **Interactive HTML** (`mockup-generator.html`) - Open in a web browser for the best viewing experience with full styling and emoji icons
2. **SVG Files** - Individual screen mockups (note: some characters may not render correctly in all SVG viewers)

## Screens Covered

### Inner Display (Unfolded)

| Screen | File | Description |
|--------|------|-------------|
| Home | `home-inner.svg` | Main home screen with inspection start, last result, and quick actions |
| Hinge Sweep | `hinge-sweep.svg` | Live hinge angle display during sweep test with chart |
| Summary | `summary.svg` | Inspection completion summary with score and test results |
| Report Preview | `report-preview.svg` | PDF report preview showing device info, results, and signature |
| Verify | `verify.svg` | Report verification screen with QR scanner and validity display |

### Outer Display (Cover - Folded)

| Screen | File | Description |
|--------|------|-------------|
| Cover Home | `cover-outer.svg` | Compact home for cover display with last check and quick test button |

### Split View (Partially Folded)

See `mockup-generator.html` for the crease test split view showing instructions on one half and test pattern on the other.

## Key UI Components

### Color Scheme
- **Pass**: Green (#34c759 / #d1fae5 background)
- **Attention**: Amber/Orange (#f59e0b / #fef3c7 background)
- **Fail**: Red (#dc2626 / #fee2e2 background)
- **Primary Action**: Blue (#007aff)

### Typography
- SF Pro (system font)
- SF Mono for IDs and technical data
- Dynamic Type support (all non-canvas screens)

### Components
- `ResultBadge` - Pass/Attention/Fail indicator with icon
- `QuickActionCard` - Grid card for quick actions
- `TestResultRow` - List item showing test outcome
- `InfoRow` - Label/value pair for report details
- `ProgressBar` - Test progress indicator
- `SignatureBadge` - Digital signature status

## Design Principles

1. **Clinical but friendly** - Clean, precise UI with trust colors
2. **Full-bleed test canvases** - Tests use the entire screen
3. **Split layout on fold** - Instructions left, visuals right when partially open
4. **Accessibility first** - VoiceOver support, high contrast, large touch targets
5. **Honest limitations** - Clear disclaimers about what the app can/cannot verify

## Screenshots for App Store

Recommended screenshots based on these mockups:
1. Touch grid along the crease (showing dense crease band)
2. Hinge sweep chart with live angle
3. PDF report with QR code
4. History compare view
