import XCTest
@testable import RosterFocusCore

final class ShortcutsParseTests: XCTestCase {
    /// `shortcuts list` is one name per line; names may contain typographic
    /// apostrophes/ellipses and must survive parsing intact.
    func testParsePreservesNamesAndTrims() {
        let output = """
        Work Focus On
        Work Focus Off
        Mom’s Birthday Reminder
        Wind Down…
          Leading Spaces

        """
        let names = ShortcutsService.parseList(output)
        XCTAssertTrue(names.contains("Work Focus On"))
        XCTAssertTrue(names.contains("Work Focus Off"))
        XCTAssertTrue(names.contains("Mom’s Birthday Reminder"))   // typographic apostrophe
        XCTAssertTrue(names.contains("Wind Down…"))                // ellipsis
        XCTAssertTrue(names.contains("Leading Spaces"))            // trimmed
        XCTAssertFalse(names.contains(""))                         // blank line dropped
        XCTAssertEqual(names.count, 5)
    }

    /// CRLF output must still split into clean names (Swift treats "\r\n" as one
    /// Character, so a naive split on "\n" would not split it).
    func testParseHandlesCRLF() {
        let names = ShortcutsService.parseList("Work Focus On\r\nDeep Work\r\n")
        XCTAssertEqual(names, ["Work Focus On", "Deep Work"])
        XCTAssertFalse(names.contains("Work Focus On\r"))   // no stray carriage return
    }
}
