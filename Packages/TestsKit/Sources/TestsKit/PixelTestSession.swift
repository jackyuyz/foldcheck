import Foundation

/// Full-screen solid colors shown by the dead/stuck pixel test (T2), in order.
public enum PixelTestPattern: String, Codable, Sendable, CaseIterable, Equatable {
    case black, white, red, green, blue, gray50

    /// Absolute sRGB components 0…1 (test patterns never adapt to light/dark mode).
    public var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .black: return (0, 0, 0)
        case .white: return (1, 1, 1)
        case .red: return (1, 0, 0)
        case .green: return (0, 1, 0)
        case .blue: return (0, 0, 1)
        case .gray50: return (0.5, 0.5, 0.5)
        }
    }

    /// Whether overlaid UI should be drawn light (on dark patterns) or dark.
    public var prefersLightForeground: Bool {
        switch self {
        case .black, .red, .blue, .gray50: return true
        case .white, .green: return false
        }
    }

    /// Position in `allCases`, used in metric values.
    public var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

/// A spot the user tapped because a pixel looked dead, stuck, or discolored.
public struct PixelIssueMark: Codable, Sendable, Equatable {
    public var pattern: PixelTestPattern
    /// Normalized 0…1 position on the canvas.
    public var x: Double
    public var y: Double

    public init(pattern: PixelTestPattern, x: Double, y: Double) {
        self.pattern = pattern
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }
}

/// State of one pixel test run (T2).
public struct PixelTestSession: Sendable, Equatable {
    /// At most this many marks are stored as metrics.
    public static let maxStoredMarks = 50

    public let patterns: [PixelTestPattern]
    public private(set) var currentIndex = 0
    public private(set) var marks: [PixelIssueMark] = []
    public private(set) var isFinished = false

    public init(patterns: [PixelTestPattern] = PixelTestPattern.allCases) {
        self.patterns = patterns.isEmpty ? PixelTestPattern.allCases : patterns
    }

    public var currentPattern: PixelTestPattern {
        patterns[min(currentIndex, patterns.count - 1)]
    }

    public var isLastPattern: Bool {
        currentIndex >= patterns.count - 1
    }

    /// Marks for the pattern on screen now.
    public var currentMarks: [PixelIssueMark] {
        marks.filter { $0.pattern == currentPattern }
    }

    /// Records an issue at a normalized point on the current pattern.
    public mutating func mark(x: Double, y: Double) {
        guard !isFinished else { return }
        marks.append(PixelIssueMark(pattern: currentPattern, x: x, y: y))
    }

    /// Removes the most recent mark on the current pattern.
    public mutating func undoLastMark() {
        guard let index = marks.lastIndex(where: { $0.pattern == currentPattern }) else { return }
        marks.remove(at: index)
    }

    /// Moves to the next color. Returns true when the last color has been dismissed.
    @discardableResult
    public mutating func advance() -> Bool {
        if isLastPattern {
            isFinished = true
        } else {
            currentIndex += 1
        }
        return isFinished
    }

    public func markCount(for pattern: PixelTestPattern) -> Int {
        marks.filter { $0.pattern == pattern }.count
    }

    /// No marks is Pass. Any mark is Attention: the marks are the user's observations,
    /// and one stuck pixel may be tapped several times, so the count alone never means Fail.
    public static func outcome(markCount: Int) -> TestOutcome {
        markCount == 0 ? .pass : .attention
    }

    public func result(display: DisplayKind?, notes: String = "", finishedAt: Date = .now) -> TestResult {
        var metrics: [String: Double] = [
            TestMetricKey.issuesMarked: Double(marks.count),
            TestMetricKey.patternsShown: Double(isFinished ? patterns.count : currentIndex + 1),
        ]
        for pattern in patterns {
            metrics[TestMetricKey.pixelIssues(pattern)] = Double(markCount(for: pattern))
        }
        for (n, mark) in marks.prefix(Self.maxStoredMarks).enumerated() {
            metrics[TestMetricKey.pixelMarkX(n)] = mark.x
            metrics[TestMetricKey.pixelMarkY(n)] = mark.y
            metrics[TestMetricKey.pixelMarkPattern(n)] = Double(mark.pattern.index)
        }
        return TestResult(
            id: .pixels,
            outcome: Self.outcome(markCount: marks.count),
            metrics: metrics,
            notes: notes,
            display: display,
            finishedAt: finishedAt
        )
    }
}
