import XCTest
@testable import RosterFocusCore

final class ConfigRoundTripTests: XCTestCase {
    /// Decodes config with `_comment` annotations + defaults, like config.example.json.
    func testDecodeIgnoresCommentsAndAppliesDefaults() throws {
        let json = """
        {
          "_comment": "top-level note",
          "rules": [
            { "_comment": "rule note", "calendar": "Work", "focus": "Work",
              "on_shortcut": "Work Focus On", "off_shortcut": "Work Focus Off" },
            { "calendar": "Work", "keyword": "Gym", "focus": "Fitness",
              "on_shortcut": "F On", "off_shortcut": "F Off",
              "lead_minutes": 5, "trail_minutes": 10 }
          ]
        }
        """
        let cfg = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        XCTAssertEqual(cfg.rules.count, 2)

        let r0 = cfg.rules[0]
        XCTAssertEqual(r0.calendar, "Work")
        XCTAssertEqual(r0.keyword, "")        // default
        XCTAssertEqual(r0.leadMinutes, 0)     // default
        XCTAssertEqual(r0.trailMinutes, 0)    // default

        let r1 = cfg.rules[1]
        XCTAssertEqual(r1.keyword, "Gym")
        XCTAssertEqual(r1.normalizedKeyword, "gym")
        XCTAssertEqual(r1.leadMinutes, 5)
        XCTAssertEqual(r1.trailMinutes, 10)
    }

    /// Re-encoding produces the snake_case keys the Python CLI expects.
    func testEncodeUsesSnakeCaseKeys() throws {
        let cfg = Config(rules: [
            Rule(calendar: "Work", focus: "Work", onShortcut: "On", offShortcut: "Off",
                 leadMinutes: 5, trailMinutes: 0)
        ])
        let data = try JSONEncoder().encode(cfg)
        let s = String(data: data, encoding: .utf8)!
        XCTAssertTrue(s.contains("\"on_shortcut\""))
        XCTAssertTrue(s.contains("\"off_shortcut\""))
        XCTAssertTrue(s.contains("\"lead_minutes\""))
        XCTAssertTrue(s.contains("\"trail_minutes\""))
        XCTAssertFalse(s.contains("\"onShortcut\""))
        XCTAssertFalse(s.contains("\"id\""))   // synthesized id must not leak into JSON
    }

    func testRoundTripPreservesContent() throws {
        let original = Config(rules: [
            Rule(calendar: "On-Call", focus: "Do Not Disturb",
                 onShortcut: "DND On", offShortcut: "DND Off"),
            Rule(calendar: "Work", keyword: "night", focus: "Sleep",
                 onShortcut: "S On", offShortcut: "S Off", leadMinutes: 0, trailMinutes: 15),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded.rules, original.rules)   // content equality (ignores id)
    }

    /// Numeric fields are coerced from Int, Double, or numeric String (matching the
    /// Python CLI's int()), so a hand-edited quoted number doesn't reject the config.
    func testTolerantNumericDecode() throws {
        let json = """
        {"rules":[
          {"calendar":"Work","focus":"Work","on_shortcut":"On","off_shortcut":"Off",
           "lead_minutes":"5","trail_minutes":10.0}
        ]}
        """
        let cfg = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        XCTAssertEqual(cfg.rules[0].leadMinutes, 5)    // "5" string → 5
        XCTAssertEqual(cfg.rules[0].trailMinutes, 10)  // 10.0 double → 10
    }
}
