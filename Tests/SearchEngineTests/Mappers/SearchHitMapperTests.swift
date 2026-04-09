//
//  SearchHitMapperTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchHitMapper의 변환 규칙을 확인하는 테스트입니다.

 검색 결과는 문서 원본과 부가 검색 정보를 함께 담고 있으므로,
 문서 복원 규칙과 스니펫 정규화 규칙이 흔들리면 화면 표시가 불안정해질 수 있습니다.
 이 테스트는 점수, 문서, 스니펫이 공개 모델로 일관되게 변환되는지 검증합니다.
 */
final class SearchHitMapperTests: XCTestCase {
    /*
     SearchHit ManagedObject가 공개 SearchHit 모델로 변환되는지 검증합니다.
     */
    func test_toSearchHit_returnsMappedHit() {
        let managedObject = SearchHitMO(
            id: "notice-1",
            scope: "app.notice",
            title: "Search Engine",
            body: "SQLite full text search",
            keywords: "swift\nfts",
            lastUpdatedAt: 200,
            score: -1.25,
            titleSnippet: "<b>Search</b> Engine",
            bodySnippet: "SQLite <b>full</b> text search"
        )

        let hit = SearchHitMapper.toSearchHit(managedObject)

        XCTAssertEqual(hit.document.id, "notice-1")
        XCTAssertEqual(hit.document.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertEqual(hit.document.title, "Search Engine")
        XCTAssertEqual(hit.document.body, "SQLite full text search")
        XCTAssertEqual(hit.document.keywords, ["swift", "fts"])
        XCTAssertEqual(hit.document.lastUpdatedAt.timeIntervalSince1970, 200, accuracy: 0.0001)
        XCTAssertEqual(hit.score, -1.25, accuracy: 0.0001)
        XCTAssertEqual(hit.snippet, SearchSnippet(
            title: "<b>Search</b> Engine",
            body: "SQLite <b>full</b> text search"
        ))
    }

    /*
     공백 스니펫은 nil로 정리되어 불필요한 SearchSnippet 생성이 방지되는지 검증합니다.
     */
    func test_toSearchHit_withBlankSnippets_returnsNilSnippet() {
        let managedObject = SearchHitMO(
            id: "notice-1",
            scope: "app.notice",
            title: "Search Engine",
            body: "SQLite full text search",
            keywords: "swift",
            lastUpdatedAt: 200,
            score: -1.25,
            titleSnippet: "   ",
            bodySnippet: nil
        )

        let hit = SearchHitMapper.toSearchHit(managedObject)

        XCTAssertNil(hit.snippet)
    }
}
