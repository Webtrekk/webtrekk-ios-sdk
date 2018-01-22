import Foundation

enum PropertyValue {
    case value(String)
    case key(String)

    func serialized(for event: TrackingEvent) -> String? {
        return serialized(variables: event.variables)
    }

    func serialized(variables: [String: String]) -> String? {
        switch self {
        case let .value(value):
            return value
        case let .key(key):
            return variables[key]
        }
    }

    func serialized() -> String? {
        switch self {
        case let .value(value):
            return value
        case let .key(key):
            _ = key
            return nil
        }
    }
}
