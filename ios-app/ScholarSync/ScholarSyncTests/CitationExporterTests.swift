import XCTest
@testable import ScholarSync

final class CitationExporterTests: XCTestCase {

    let samplePaper = Paper(
        title: "Attention Is All You Need",
        authors: "Ashish Vaswani, Noam Shazeer",
        journal: "NeurIPS",
        year: 2017,
        doi: "10.48550/arXiv.1706.03762",
        status: .unread
    )

    // MARK: - BibTeX

    func testBibTeXFormat() {
        let output = CitationExporter.export(papers: [samplePaper], format: .bibtex)
        XCTAssertTrue(output.contains("@article{"))
        XCTAssertTrue(output.contains("title={Attention Is All You Need}"))
        XCTAssertTrue(output.contains("year={2017}"))
        XCTAssertTrue(output.contains("doi={10.48550/arXiv.1706.03762}"))
    }

    func testBibTeXAuthorsJoinedWithAnd() {
        let output = CitationExporter.export(papers: [samplePaper], format: .bibtex)
        XCTAssertTrue(output.contains("author={Ashish Vaswani and Noam Shazeer}"))
    }

    // MARK: - RIS

    func testRISFormat() {
        let output = CitationExporter.export(papers: [samplePaper], format: .ris)
        XCTAssertTrue(output.contains("TY  - JOUR"))
        XCTAssertTrue(output.contains("TI  - Attention Is All You Need"))
        XCTAssertTrue(output.contains("PY  - 2017"))
        XCTAssertTrue(output.contains("DO  - 10.48550/arXiv.1706.03762"))
        XCTAssertTrue(output.contains("ER  - "))
    }

    func testRISMultipleAuthors() {
        let output = CitationExporter.export(papers: [samplePaper], format: .ris)
        XCTAssertTrue(output.contains("AU  - Ashish Vaswani"))
        XCTAssertTrue(output.contains("AU  - Noam Shazeer"))
    }

    // MARK: - CSV

    func testCSVHeader() {
        let output = CitationExporter.export(papers: [samplePaper], format: .csv)
        let lines = output.components(separatedBy: "\n")
        XCTAssertEqual(lines.first, "Title,Authors,Journal,Year,DOI")
    }

    func testCSVDataRow() {
        let output = CitationExporter.export(papers: [samplePaper], format: .csv)
        XCTAssertTrue(output.contains("\"Attention Is All You Need\""))
        XCTAssertTrue(output.contains("\"Ashish Vaswani, Noam Shazeer\""))
        XCTAssertTrue(output.contains("2017"))
    }

    func testCSVEscapesQuotes() {
        let paper = Paper(
            title: "A \"Quoted\" Title",
            authors: "Author",
            year: 2024,
            status: .unread
        )
        let output = CitationExporter.export(papers: [paper], format: .csv)
        // Embedded quotes should be doubled
        XCTAssertTrue(output.contains("\"\"Quoted\"\""))
    }

    // MARK: - Multiple Papers

    func testMultiplePapersBibTeX() {
        let paper2 = Paper(title: "BERT", authors: "Jacob Devlin", year: 2019, status: .read)
        let output = CitationExporter.export(papers: [samplePaper, paper2], format: .bibtex)
        let entries = output.components(separatedBy: "@article{").count - 1
        XCTAssertEqual(entries, 2)
    }
}
