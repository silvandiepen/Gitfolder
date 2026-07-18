import XCTest
@testable import GitKanban

/// Verifies the card-description Markdown parser splits a document into the right
/// block structure (the detail view renders these blocks).
final class MarkdownTests: XCTestCase {
    func testBlockParsing() {
        let blocks = MarkdownView.parse("""
        # Heading One
        Some **bold** and *italic* text
        that wraps across lines.

        ## Subheading
        - first bullet
        - second bullet

        1. step one
        2. step two

        > a block quote

        ```
        let x = 1
        ```
        """)

        // Expected order of block kinds.
        var kinds: [String] = []
        for block in blocks {
            switch block {
            case .heading: kinds.append("heading")
            case .paragraph: kinds.append("paragraph")
            case .bullets: kinds.append("bullets")
            case .numbered: kinds.append("numbered")
            case .quote: kinds.append("quote")
            case .code: kinds.append("code")
            }
        }
        XCTAssertEqual(kinds, ["heading", "paragraph", "heading", "bullets", "numbered", "quote", "code"])

        // Spot-check contents.
        if case let .heading(level, text) = blocks[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(text, "Heading One")
        } else { XCTFail("first block should be a heading") }

        if case let .bullets(items) = blocks[3] {
            XCTAssertEqual(items, ["first bullet", "second bullet"])
        } else { XCTFail("expected bullets") }

        if case let .numbered(items) = blocks[4] {
            XCTAssertEqual(items, ["step one", "step two"])
        } else { XCTFail("expected numbered") }

        if case let .code(code) = blocks[6] {
            XCTAssertEqual(code, "let x = 1")
        } else { XCTFail("expected code") }
    }

    func testPlainTextIsOneParagraph() {
        let blocks = MarkdownView.parse("Just a single line of text.")
        XCTAssertEqual(blocks.count, 1)
        if case let .paragraph(text) = blocks[0] {
            XCTAssertEqual(text, "Just a single line of text.")
        } else { XCTFail("expected a paragraph") }
    }
}
