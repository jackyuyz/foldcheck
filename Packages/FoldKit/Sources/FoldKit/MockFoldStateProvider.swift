import Foundation

/// A step in a fold state animation script.
public struct FoldScriptStep: Sendable, Codable {
    public var posture: FoldPosture
    public var angleDegrees: Double?
    public var durationSeconds: Double
    
    public init(posture: FoldPosture, angleDegrees: Double? = nil, durationSeconds: Double = 0) {
        self.posture = posture
        self.angleDegrees = angleDegrees
        self.durationSeconds = durationSeconds
    }
    
    /// Create a sweep from one angle to another
    public static func sweep(from: Double, to: Double, durationSeconds: Double, sampleRate: Double = 30) -> [FoldScriptStep] {
        let stepCount = Int(durationSeconds * sampleRate)
        guard stepCount > 0 else { return [] }
        
        let stepDuration = durationSeconds / Double(stepCount)
        let angleStep = (to - from) / Double(stepCount)
        
        return (0...stepCount).map { i in
            let angle = from + angleStep * Double(i)
            let posture: FoldPosture
            if angle < 10 {
                posture = .closed
            } else if angle > 170 {
                posture = .fullyOpen
            } else {
                posture = .partiallyOpen
            }
            return FoldScriptStep(posture: posture, angleDegrees: angle, durationSeconds: stepDuration)
        }
    }
}

/// Thread-safe box holding the latest mock state for synchronous reads.
private final class StateSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: FoldState

    init(_ value: FoldState) {
        _value = value
    }

    var value: FoldState {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

/// Test / preview / UI-test provider. Driven by code or by launch arguments.
///
/// Launch argument `-FoldMock <value>` values:
/// - `nohinge`: No hinge device
/// - `closed`: Closed posture
/// - `open`: Fully open posture
/// - `half:<deg>`: Partially open at specified degrees
/// - `sweep:<from>-<to>:<seconds>`: Animated sweep
/// - `script:<bundled-json-name>`: Load script from bundle
public actor MockFoldStateProvider: FoldStateProvider {
    private var _state: FoldState {
        didSet { snapshot.value = _state }
    }
    private var continuations: [UUID: AsyncStream<FoldState>.Continuation] = [:]
    private var scriptTask: Task<Void, Never>?
    /// Lock-protected copy of `_state` so `state` can be read synchronously from any context
    /// (including the main actor) without hopping onto this actor.
    private nonisolated let snapshot: StateSnapshot
    
    public init(initialState: FoldState = .noHinge) {
        self._state = initialState
        self.snapshot = StateSnapshot(initialState)
    }
    
    nonisolated public var state: FoldState {
        snapshot.value
    }
    
    nonisolated public func states() -> AsyncStream<FoldState> {
        AsyncStream { continuation in
            Task {
                let currentState = await self._state
                continuation.yield(currentState)
                await self.addContinuation(continuation: continuation)
            }
        }
    }
    
    private func addContinuation(continuation: AsyncStream<FoldState>.Continuation) {
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.removeContinuation(id: id)
            }
        }
    }
    
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
    
    /// Set a specific posture and angle
    public func set(_ posture: FoldPosture, angle: Double? = nil) {
        let newState = FoldState(posture: posture, angleDegrees: angle, timestamp: .now)
        _state = newState
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }
    
    /// Play a scripted sequence of fold states
    public func play(_ script: [FoldScriptStep]) async {
        scriptTask?.cancel()
        
        scriptTask = Task {
            for step in script {
                guard !Task.isCancelled else { break }
                
                let newState = FoldState(
                    posture: step.posture,
                    angleDegrees: step.angleDegrees,
                    timestamp: .now
                )
                _state = newState
                for continuation in continuations.values {
                    continuation.yield(newState)
                }
                
                if step.durationSeconds > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step.durationSeconds * 1_000_000_000))
                }
            }
        }
        
        await scriptTask?.value
    }
    
    /// The script given at launch (`sweep:` / `script:`), replayed when a hinge test starts
    /// recording so UI tests and the simulator behave like a user moving the hinge on cue.
    public private(set) var launchScript: [FoldScriptStep]?

    public func setLaunchScript(_ script: [FoldScriptStep]?) {
        launchScript = script
    }

    /// Jumps to the launch script's first step (so a recording can start there without a
    /// jump from wherever the last run ended). Returns false when there is no launch script.
    @discardableResult
    public func rewindLaunchScript() -> Bool {
        guard let first = launchScript?.first else { return false }
        stop()
        set(first.posture, angle: first.angleDegrees)
        return true
    }

    /// Plays the launch script from the start, if there is one.
    public func replayLaunchScript() async {
        guard let launchScript else { return }
        await play(launchScript)
    }

    /// Stop any running script
    public func stop() {
        scriptTask?.cancel()
        scriptTask = nil
    }
    
    /// Parse a launch argument value into the appropriate mock state
    /// Parse a launch argument value into the appropriate mock state.
    /// - Parameter loadScript: Loads `script:<name>` steps (the app reads bundled JSON).
    public static func parseArgument(
        _ value: String,
        loadScript: (String) -> [FoldScriptStep]? = { _ in nil }
    ) -> (posture: FoldPosture, angle: Double?, script: [FoldScriptStep]?) {
        let lowercased = value.lowercased()
        
        if lowercased == "nohinge" {
            return (.noHinge, nil, nil)
        } else if lowercased == "closed" {
            return (.closed, 0, nil)
        } else if lowercased == "open" {
            return (.fullyOpen, 180, nil)
        } else if lowercased.hasPrefix("half:") {
            let angleStr = String(lowercased.dropFirst(5))
            if let angle = Double(angleStr) {
                return (.partiallyOpen, angle, nil)
            }
        } else if lowercased.hasPrefix("sweep:") {
            // Format: sweep:<from>-<to>:<seconds>
            let params = String(lowercased.dropFirst(6))
            let parts = params.split(separator: ":")
            if parts.count == 2,
               let seconds = Double(parts[1]) {
                let angleParts = parts[0].split(separator: "-")
                if angleParts.count == 2,
                   let from = Double(angleParts[0]),
                   let to = Double(angleParts[1]) {
                    let script = FoldScriptStep.sweep(from: from, to: to, durationSeconds: seconds)
                    return (.partiallyOpen, from, script)
                }
            }
        } else if value.lowercased().hasPrefix("script:") {
            // Format: script:<bundled-json-name>. The name keeps its case for the file lookup.
            let name = String(value.dropFirst(7))
            if let script = loadScript(name), let first = script.first {
                return (first.posture, first.angleDegrees, script)
            }
        }
        
        return (.noHinge, nil, nil)
    }

    /// Decodes a script file: a JSON array of `FoldScriptStep`.
    public static func decodeScript(_ data: Data) -> [FoldScriptStep]? {
        try? JSONDecoder().decode([FoldScriptStep].self, from: data)
    }
}
