import Testing
@testable import HingeInput

@Test("Manual input stays in slider bounds and rejects non-finite sensor values")
func initialAngle() {
    #expect(ManualHingeAngle.clamped(-10) == 0)
    #expect(ManualHingeAngle.clamped(200) == 180)
    #expect(ManualHingeAngle.clamped(95) == 95)
    #expect(ManualHingeAngle.clamped(nil) == 90)
    #expect(ManualHingeAngle.clamped(.nan) == 90)
    #expect(ManualHingeAngle.clamped(.infinity) == 90)
}
