import Foundation

/// One mapping from a calendar (optionally filtered by a title keyword) to a Focus,
/// plus the Shortcuts that turn that Focus on/off. JSON is byte-compatible with the
/// Python CLI's config (snake_case keys, same defaults as `normalize_rules`).
public struct Rule: Codable, Identifiable {
    public var id = UUID()
    public var calendar: String
    public var keyword: String        // "" matches any event; matched case-insensitively as a substring
    public var focus: String
    public var onShortcut: String
    public var offShortcut: String
    public var leadMinutes: Int
    public var trailMinutes: Int

    enum CodingKeys: String, CodingKey {
        case calendar, keyword, focus
        case onShortcut = "on_shortcut"
        case offShortcut = "off_shortcut"
        case leadMinutes = "lead_minutes"
        case trailMinutes = "trail_minutes"
    }

    public init(calendar: String, keyword: String = "", focus: String,
                onShortcut: String, offShortcut: String,
                leadMinutes: Int = 0, trailMinutes: Int = 0) {
        self.calendar = calendar
        self.keyword = keyword
        self.focus = focus
        self.onShortcut = onShortcut
        self.offShortcut = offShortcut
        self.leadMinutes = leadMinutes
        self.trailMinutes = trailMinutes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calendar = try c.decode(String.self, forKey: .calendar)
        keyword = try c.decodeIfPresent(String.self, forKey: .keyword) ?? ""
        focus = try c.decode(String.self, forKey: .focus)
        onShortcut = try c.decode(String.self, forKey: .onShortcut)
        offShortcut = try c.decode(String.self, forKey: .offShortcut)
        leadMinutes = Rule.flexibleInt(c, .leadMinutes)
        trailMinutes = Rule.flexibleInt(c, .trailMinutes)
        id = UUID()
    }

    /// Tolerant numeric decode (Int, Double, or numeric String → Int), matching the
    /// Python CLI's `int(r.get(...))`, so a hand-edited `"5"` or `5.0` doesn't reject
    /// the whole config. Absent/unparseable → 0.
    private static func flexibleInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? c.decode(String.self, forKey: key) {
            if let i = Int(s) { return i }
            if let d = Double(s) { return Int(d) }
        }
        return 0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(calendar, forKey: .calendar)
        try c.encode(keyword, forKey: .keyword)
        try c.encode(focus, forKey: .focus)
        try c.encode(onShortcut, forKey: .onShortcut)
        try c.encode(offShortcut, forKey: .offShortcut)
        try c.encode(leadMinutes, forKey: .leadMinutes)
        try c.encode(trailMinutes, forKey: .trailMinutes)
    }

    /// keyword normalized to lowercase, mirroring the Python `normalize_rules`.
    public var normalizedKeyword: String { keyword.lowercased() }
}

extension Rule: Equatable {
    /// Content equality, ignoring the synthesized `id` so decoded rules compare equal.
    public static func == (l: Rule, r: Rule) -> Bool {
        l.calendar == r.calendar && l.keyword == r.keyword && l.focus == r.focus &&
        l.onShortcut == r.onShortcut && l.offShortcut == r.offShortcut &&
        l.leadMinutes == r.leadMinutes && l.trailMinutes == r.trailMinutes
    }
}
