import Foundation
import TestsKit

/// Decodes saved records only when their payloads change. Hinge angles and timestamps do
/// not affect the dashboard; only a change in applicable parts needs a new aggregation.
public struct DeviceHealthCache {
    public private(set) var health: DeviceHealth?
    private var payloads: [Data] = []
    private var sessions: [InspectionSession] = []
    private var components: [HealthComponent] = []

    public init() {}

    /// Returns true when the dashboard was recomputed, including its initial empty state.
    @discardableResult
    public mutating func update(payloads newPayloads: [Data], context: DeviceContext) -> Bool {
        let applicable = HealthComponent.allCases.filter { $0.applies(to: context) }
        let recordsChanged = payloads != newPayloads
        guard health == nil || recordsChanged || components != applicable else { return false }
        if recordsChanged {
            let decoder = JSONDecoder()
            sessions = newPayloads.compactMap { try? decoder.decode(InspectionSession.self, from: $0) }
            payloads = newPayloads
        }
        components = applicable
        health = DeviceHealth(sessions: sessions, context: context)
        return true
    }
}
