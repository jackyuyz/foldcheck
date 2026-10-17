#if DEBUG
import Foundation

enum UITestConfiguration {
    static func autoCompletesTests(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        guard arguments.contains("-UITestMode"),
              let index = arguments.firstIndex(of: "-AutoCompleteTests"),
              index + 1 < arguments.count else { return false }
        return arguments[index + 1] == "pass"
    }
}
#endif
