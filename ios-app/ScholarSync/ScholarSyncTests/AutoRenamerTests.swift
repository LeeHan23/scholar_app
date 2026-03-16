import XCTest
@testable import ScholarSync

final class AutoRenamerTests: XCTestCase {

    func testBasicFilename() {
        let paper = Paper(
            title: "Attention Is All You Need",
            authors: "Ashish Vaswani, Noam Shazeer",
            journal: "NeurIPS",
            year: 2017,
            doi: "10.48550/arXiv.1706.03762",
            status: .unread
        )
        let filename = AutoRenamer.generateCleanFilename(for: paper)
        XCTAssertEqual(filename, "Vaswani_2017_Attention_Is_All_You.pdf")
    }

    func testSingleAuthor() {
        let paper = Paper(
            title: "Deep Learning",
            authors: "Ian Goodfellow",
            year: 2016,
            status: .unread
        )
        let filename = AutoRenamer.generateCleanFilename(for: paper)
        XCTAssertEqual(filename, "Goodfellow_2016_Deep_Learning.pdf")
    }

    func testSpecialCharactersRemoved() {
        let paper = Paper(
            title: "What's New? (A Survey)",
            authors: "Jane O'Brien",
            year: 2023,
            status: .unread
        )
        let filename = AutoRenamer.generateCleanFilename(for: paper)
        // Special chars like ', (, ) should be stripped
        XCTAssertFalse(filename.contains("'"))
        XCTAssertFalse(filename.contains("("))
        XCTAssertTrue(filename.hasSuffix(".pdf"))
    }

    func testShortTitle() {
        let paper = Paper(
            title: "BERT",
            authors: "Jacob Devlin",
            year: 2019,
            status: .unread
        )
        let filename = AutoRenamer.generateCleanFilename(for: paper)
        XCTAssertEqual(filename, "Devlin_2019_BERT.pdf")
    }
}
