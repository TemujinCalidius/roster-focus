import Foundation

/// The whole config: an ordered, priority-ranked list of rules. Unknown keys
/// (like the `_comment` annotations in config.example.json) are ignored on decode.
public struct Config: Codable {
    public var rules: [Rule]
    public init(rules: [Rule] = []) { self.rules = rules }
}
