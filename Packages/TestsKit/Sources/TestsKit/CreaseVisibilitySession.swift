import Foundation

/// The three guided viewing angles for the crease visibility test (T3).
public enum CreaseViewingAngle: Int, Codable, Sendable, CaseIterable, Equatable {
    /// Flat, looking straight at the crease.
    case straightOn = 1
    /// Flat, tilted ~45° under side light.
    case tiltedSideLight = 2
    /// Folded to ~90°, looking along the crease.
    case foldedNinety = 3
}

/// State of one crease visibility run (T3): a 1–5 rating per viewing angle,
/// the hinge angle at the moment of rating (if any), and optional imported photos.
public struct CreaseVisibilitySession: Sendable, Equatable {
    public static let ratingRange = 1...5

    public let views: [CreaseViewingAngle]
    public private(set) var currentIndex = 0
    public private(set) var ratings: [CreaseViewingAngle: Int] = [:]
    public private(set) var hingeAngles: [CreaseViewingAngle: Double] = [:]
    public private(set) var attachments: [String] = []
    public private(set) var isFinished = false

    public init(views: [CreaseViewingAngle] = CreaseViewingAngle.allCases) {
        self.views = views.isEmpty ? CreaseViewingAngle.allCases : views
    }

    public var currentView: CreaseViewingAngle {
        views[min(currentIndex, views.count - 1)]
    }

    public var currentRating: Int? {
        ratings[currentView]
    }

    public var isLastView: Bool {
        currentIndex >= views.count - 1
    }

    public var canAdvance: Bool {
        currentRating != nil
    }

    /// Rates the current view. Values outside 1…5 are ignored.
    /// - Parameter hingeAngle: The hinge angle while rating, if the device reports one.
    public mutating func rate(_ rating: Int, hingeAngle: Double? = nil) {
        guard Self.ratingRange.contains(rating), !isFinished else { return }
        ratings[currentView] = rating
        hingeAngles[currentView] = hingeAngle
    }

    /// Moves to the next view once the current one is rated. Returns true when finished.
    @discardableResult
    public mutating func advance() -> Bool {
        guard canAdvance else { return false }
        if isLastView {
            isFinished = true
        } else {
            currentIndex += 1
        }
        return isFinished
    }

    public mutating func goBack() {
        guard currentIndex > 0, !isFinished else { return }
        currentIndex -= 1
    }

    public mutating func attach(_ filename: String) {
        guard !filename.isEmpty, !attachments.contains(filename) else { return }
        attachments.append(filename)
    }

    public mutating func removeAttachments() {
        attachments.removeAll()
    }

    /// Mean of the given ratings, or `nil` when there are none.
    public var averageRating: Double? {
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.values.reduce(0, +)) / Double(ratings.count)
    }

    public var worstRating: Int? {
        ratings.values.max()
    }

    /// Crease visibility is cosmetic and subjective, so this test never Fails:
    /// every view at 3 or below is Pass; any view rated 4 or 5 is Attention.
    public static func outcome(worstRating: Int?) -> TestOutcome {
        guard let worstRating else { return .skipped }
        return worstRating <= 3 ? .pass : .attention
    }

    public func result(display: DisplayKind?, notes: String = "", finishedAt: Date = .now) -> TestResult {
        var metrics: [String: Double] = [
            TestMetricKey.viewingAngles: Double(ratings.count),
            TestMetricKey.photoAttached: attachments.isEmpty ? 0 : 1,
        ]
        if let averageRating {
            metrics[TestMetricKey.creaseRating] = (averageRating * 10).rounded() / 10
        }
        if let worstRating {
            metrics[TestMetricKey.creaseRatingMax] = Double(worstRating)
        }
        for view in views {
            if let rating = ratings[view] {
                metrics[TestMetricKey.creaseRating(view)] = Double(rating)
            }
            if let angle = hingeAngles[view] {
                metrics[TestMetricKey.creaseHingeAngle(view)] = angle
            }
        }
        return TestResult(
            id: .crease,
            outcome: Self.outcome(worstRating: worstRating),
            metrics: metrics,
            notes: notes,
            display: display,
            attachments: attachments,
            finishedAt: finishedAt
        )
    }
}
