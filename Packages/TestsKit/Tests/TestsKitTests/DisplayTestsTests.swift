import Testing
import Foundation
@testable import TestsKit

@Suite("Pixel test session")
struct PixelTestSessionTests {
    @Test("Patterns run black, white, red, green, blue, 50% gray")
    func order() {
        let session = PixelTestSession()
        #expect(session.patterns == [.black, .white, .red, .green, .blue, .gray50])
        #expect(session.currentPattern == .black)
        #expect(PixelTestPattern.gray50.rgb.red == 0.5)
        #expect(PixelTestPattern.red.rgb == (1, 0, 0))
    }

    @Test("Advancing through every color finishes; no marks is Pass")
    func cleanRun() {
        var session = PixelTestSession()
        var finished = false
        for _ in 0..<6 { finished = session.advance() }
        #expect(finished)
        #expect(session.isFinished)
        let result = session.result(display: .inner)
        #expect(result.id == .pixels)
        #expect(result.outcome == .pass)
        #expect(result.metrics[TestMetricKey.issuesMarked] == 0)
        #expect(result.metrics[TestMetricKey.patternsShown] == 6)
        #expect(result.display == .inner)
    }

    @Test("Marks are stored per color as normalized, clamped points; any mark is Attention")
    func marks() {
        var session = PixelTestSession()
        session.mark(x: 0.25, y: 0.75)
        session.advance()
        session.mark(x: 1.4, y: -0.2)
        session.mark(x: 0.5, y: 0.5)
        session.undoLastMark()
        #expect(session.marks.count == 2)
        #expect(session.markCount(for: .black) == 1)
        #expect(session.markCount(for: .white) == 1)
        #expect(session.currentMarks == [PixelIssueMark(pattern: .white, x: 1, y: 0)])
        let result = session.result(display: nil)
        #expect(result.outcome == .attention)
        #expect(result.metrics[TestMetricKey.issuesMarked] == 2)
        #expect(result.metrics[TestMetricKey.pixelIssues(.black)] == 1)
        #expect(result.metrics[TestMetricKey.pixelIssues(.gray50)] == 0)
        #expect(result.metrics[TestMetricKey.pixelMarkX(0)] == 0.25)
        #expect(result.metrics[TestMetricKey.pixelMarkY(0)] == 0.75)
        #expect(result.metrics[TestMetricKey.pixelMarkPattern(1)] == Double(PixelTestPattern.white.index))
        #expect(result.metrics[TestMetricKey.patternsShown] == 2)
    }

    @Test("Undo only removes marks on the current color")
    func undoScopedToColor() {
        var session = PixelTestSession()
        session.mark(x: 0.1, y: 0.1)
        session.advance()
        session.undoLastMark()
        #expect(session.marks.count == 1)
    }

    @Test("Marks after finishing are ignored; stored marks are capped")
    func limits() {
        var session = PixelTestSession(patterns: [.white])
        for i in 0..<60 { session.mark(x: Double(i) / 60, y: 0.5) }
        session.advance()
        session.mark(x: 0.5, y: 0.5)
        #expect(session.marks.count == 60)
        let result = session.result(display: nil)
        #expect(result.metrics[TestMetricKey.issuesMarked] == 60)
        #expect(result.metrics[TestMetricKey.pixelMarkX(49)] != nil)
        #expect(result.metrics[TestMetricKey.pixelMarkX(50)] == nil)
    }
}

@Suite("Crease visibility session")
struct CreaseVisibilitySessionTests {
    @Test("Three guided views must each be rated before advancing")
    func flow() {
        var session = CreaseVisibilitySession()
        #expect(session.views == [.straightOn, .tiltedSideLight, .foldedNinety])
        let advancedUnrated = session.advance()
        #expect(!advancedUnrated)
        #expect(session.currentView == .straightOn)
        session.rate(2)
        let advanced = session.advance()
        #expect(!advanced)
        #expect(session.currentView == .tiltedSideLight)
        session.rate(1)
        session.advance()
        session.rate(3, hingeAngle: 92)
        #expect(session.isLastView)
        let finished = session.advance()
        #expect(finished)
        #expect(session.isFinished)
    }

    @Test("Ratings outside 1–5 are ignored")
    func validation() {
        var session = CreaseVisibilitySession()
        session.rate(0)
        session.rate(6)
        #expect(session.currentRating == nil)
        session.rate(5)
        #expect(session.currentRating == 5)
    }

    @Test("Outcome uses the worst view: ≤3 Pass, 4–5 Attention, never Fail")
    func outcomes() {
        #expect(CreaseVisibilitySession.outcome(worstRating: 1) == .pass)
        #expect(CreaseVisibilitySession.outcome(worstRating: 3) == .pass)
        #expect(CreaseVisibilitySession.outcome(worstRating: 4) == .attention)
        #expect(CreaseVisibilitySession.outcome(worstRating: 5) == .attention)
        #expect(CreaseVisibilitySession.outcome(worstRating: nil) == .skipped)
    }

    @Test("Result carries per-view ratings, hinge angles, average, and attachments")
    func result() {
        var session = CreaseVisibilitySession()
        session.rate(1, hingeAngle: 180)
        session.advance()
        session.rate(2)
        session.advance()
        session.rate(4, hingeAngle: 95)
        session.attach("crease-photo.jpg")
        session.attach("crease-photo.jpg")
        session.advance()
        let result = session.result(display: .inner)
        #expect(result.id == .crease)
        #expect(result.outcome == .attention)
        #expect(result.metrics[TestMetricKey.creaseRating] == 2.3)
        #expect(result.metrics[TestMetricKey.creaseRatingMax] == 4)
        #expect(result.metrics[TestMetricKey.viewingAngles] == 3)
        #expect(result.metrics[TestMetricKey.creaseRating(.tiltedSideLight)] == 2)
        #expect(result.metrics[TestMetricKey.creaseHingeAngle(.straightOn)] == 180)
        #expect(result.metrics[TestMetricKey.creaseHingeAngle(.tiltedSideLight)] == nil)
        #expect(result.metrics[TestMetricKey.creaseHingeAngle(.foldedNinety)] == 95)
        #expect(result.metrics[TestMetricKey.photoAttached] == 1)
        #expect(result.attachments == ["crease-photo.jpg"])
    }

    @Test("Going back keeps earlier ratings")
    func goBack() {
        var session = CreaseVisibilitySession()
        session.rate(2)
        session.advance()
        session.goBack()
        #expect(session.currentView == .straightOn)
        #expect(session.currentRating == 2)
    }
}

@Suite("Inspection plan")
struct InspectionPlanTests {
    let m2: Set<TestID> = [.touchGridOuter, .touchGridInner, .pixels, .crease]

    @Test("Without a hinge, hinge tests are N/A and the rest are runnable or unavailable")
    func noHinge() {
        let plan = InspectionPlan(context: .mock(hasHinge: false), implemented: m2)
        #expect(plan.runnable == [.touchGridOuter, .pixels])
        #expect(plan.notApplicable == [.touchGridInner, .crease, .hingeSweep])
        #expect(plan.unavailable == [.cameras, .audio, .touchID, .sensors, .buttons])
    }

    @Test("With a hinge, both touch grids and the crease test run")
    func withHinge() {
        let plan = InspectionPlan(context: .mock(hasHinge: true), implemented: m2)
        #expect(plan.runnable == [.touchGridOuter, .touchGridInner, .pixels, .crease])
        #expect(plan.notApplicable.isEmpty)
        #expect(plan.unavailable.first == .hingeSweep)
    }

    @Test("A single quick test plans only that test")
    func singleTest() {
        let plan = InspectionPlan(tests: [.pixels], context: .mock(hasHinge: false), implemented: m2)
        #expect(plan.runnable == [.pixels])
        #expect(plan.notApplicable.isEmpty && plan.unavailable.isEmpty)
    }

    @Test("Mocked postures drive applicability", arguments: [
        (FoldPosture.noHinge, false), (.closed, true), (.partiallyOpen, true), (.fullyOpen, true), (.unknown, true),
    ])
    func postureApplicability(posture: FoldPosture, hinge: Bool) {
        let context = DeviceContext(foldState: FoldState(posture: posture, angleDegrees: nil))
        #expect(TestID.crease.isApplicable(context) == hinge)
        #expect(TestID.pixels.isApplicable(context))
    }

    @Test("Quick touch test picks the inner grid only on an open Duo")
    func quickTouch() {
        func context(_ posture: FoldPosture) -> DeviceContext {
            DeviceContext(foldState: FoldState(posture: posture, angleDegrees: nil))
        }
        #expect(InspectionPlan.quickTouchTest(for: context(.noHinge)) == .touchGridOuter)
        #expect(InspectionPlan.quickTouchTest(for: context(.closed)) == .touchGridOuter)
        #expect(InspectionPlan.quickTouchTest(for: context(.fullyOpen)) == .touchGridInner)
        #expect(InspectionPlan.quickTouchTest(for: context(.partiallyOpen)) == .touchGridInner)
    }

    @Test("Display kind follows posture")
    func displayKind() {
        #expect(DisplayKind(posture: .closed) == .outer)
        #expect(DisplayKind(posture: .fullyOpen) == .inner)
        #expect(DisplayKind(posture: .partiallyOpen) == .inner)
        #expect(DisplayKind(posture: .noHinge) == nil)
        #expect(DisplayKind(posture: .unknown) == nil)
        #expect(TestID.touchGridOuter.intendedDisplay == .outer)
        #expect(TestID.crease.intendedDisplay == .inner)
        #expect(TestID.pixels.intendedDisplay == nil)
    }
}
