//
//  SearchDocumentMapperTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SearchDocumentMapper의 변환 규칙을 확인하는 테스트입니다.
///
/// 공개 문서 모델과 SQLite 저장 표현 사이의 정규화 규칙이 흔들리면,
/// 저장과 검색 결과 복원이 서로 다른 데이터를 바라보게 됩니다.
/// 이 테스트는 scope, keywords, lastUpdatedAt 변환 규칙이 일관되게 유지되는지 검증합니다.
final class SearchDocumentMapperTests: XCTestCase {
    /// 문서를 Record 표현으로 변환할 때 scope와 keywords가 정규화되는지 검증합니다.
    func test_toRecord_normalizesScopeAndKeywords() {
        let document = SearchDocument(
            id: " document-id ",
            scope: SearchScope(rawValue: "  app.notice  "),
            title: "  Search Engine  ",
            body: "  sqlite fts indexing  ",
            keywords: [" swift ", "", " ios ", "   ", "fts5"],
            lastUpdatedAt: Date(timeIntervalSince1970: 123.45)
        )

        let record = SearchDocumentMapper.toRecord(document)

        XCTAssertEqual(record.id, "document-id")
        XCTAssertEqual(record.scope, "app.notice")
        XCTAssertEqual(record.title, "Search Engine")
        XCTAssertEqual(record.body, "sqlite fts indexing")
        XCTAssertEqual(record.keywords, "swift\nios\nfts5")
        XCTAssertEqual(record.lastUpdatedAt, 123.45, accuracy: 0.0001)
    }

    /// Record 표현을 공개 문서 모델로 복원할 때 keywords와 날짜가 올바르게 복원되는지 검증합니다.
    func test_toDocument_restoresSearchDocument() {
        let record = SearchDocumentRecord(
            id: "document-id",
            scope: "app.notice",
            title: "Search Engine",
            body: "sqlite fts indexing",
            keywords: "swift\nios\nfts5",
            lastUpdatedAt: 999.5
        )

        let document = SearchDocumentMapper.toDocument(record)

        XCTAssertEqual(document.id, "document-id")
        XCTAssertEqual(document.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertEqual(document.title, "Search Engine")
        XCTAssertEqual(document.body, "sqlite fts indexing")
        XCTAssertEqual(document.keywords, ["swift", "ios", "fts5"])
        XCTAssertEqual(document.lastUpdatedAt.timeIntervalSince1970, 999.5, accuracy: 0.0001)
    }
}
