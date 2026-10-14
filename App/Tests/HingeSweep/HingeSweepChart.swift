import SwiftUI
import Charts
import FoldL10n
import TestsKit

/// Hinge angle over time, one line per step (sweep 1, sweep 2, hold).
struct HingeSweepChart: View {
    let points: [TestSeriesPoint]
    @Environment(\.appLanguage) private var language

    var body: some View {
        Chart(Array(points.enumerated()), id: \.offset) { _, point in
            LineMark(
                x: .value("s", point.t),
                y: .value("°", point.value),
                series: .value("step", point.segment)
            )
            .foregroundStyle(by: .value("step", label(for: point.segment)))
            .interpolationMethod(.linear)
        }
        .chartYScale(domain: yDomain)
        .chartXAxisLabel("s")
        .chartYAxisLabel("°")
        .chartLegend(points.map(\.segment).max() ?? 0 > 0 ? .visible : .hidden)
        .accessibilityElement()
        .accessibilityLabel(Text(L10nKey.hingeChartLabel.text(in: language)))
        .accessibilityValue(Text(accessibilitySummary))
        .accessibilityIdentifier("hinge.chart")
    }

    private func label(for segment: Int) -> String {
        segment >= 2
            ? L10nKey.hingeChartHold.text(in: language)
            : L10nKey.hingeChartSweep.text(in: language, segment + 1)
    }

    /// 0…180 unless readings go outside it (the range is undocumented, so never clip them).
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        return min(0, values.min() ?? 0)...max(180, values.max() ?? 180)
    }

    private var accessibilitySummary: String {
        let values = points.map(\.value)
        guard let low = values.min(), let high = values.max() else { return "" }
        return "\(Int(low.rounded()))°–\(Int(high.rounded()))°"
    }
}
