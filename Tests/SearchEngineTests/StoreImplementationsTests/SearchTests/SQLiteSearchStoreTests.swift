//
//  SQLiteSearchStoreTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SQLiteSearchStore의 검색 실행 동작을 확인하는 테스트입니다.

 검색 Store는 FTS MATCH 질의, 범위 필터, 페이지네이션, 결과 복원을 함께 처리하므로
 단순 결과 존재 여부보다 정렬, 범위 제한, 스니펫 생성, 오류 차단 규칙까지 함께 보는 것이 중요합니다.
 이 테스트는 실제 in-memory SQLite 저장소 위에서 검색 결과가 기대한 규칙대로 반환되는지 검증합니다.
 */
final class SQLiteSearchStoreTests: XCTestCase {
    /*
     색인된 문서를 검색하면 일치한 문서와 스니펫이 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_returnsMatchedHitsWithSnippet() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "notice-1",
                scope: SearchScope(rawValue: "app.notice"),
                title: "Swift Search Engine",
                body: "SQLite FTS5 powers fast search results",
                keywords: ["swift", "search"],
                lastUpdatedAt: Date(timeIntervalSince1970: 100)
            ),
            makeDocument(
                id: "notice-2",
                scope: SearchScope(rawValue: "app.guide"),
                title: "Persistence Guide",
                body: "Core Data migration overview",
                keywords: ["coredata"],
                lastUpdatedAt: Date(timeIntervalSince1970: 50)
            )
        ])

        let hits = try searchStore.search(SearchQuery(text: "swift search"))

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.document.id, "notice-1")
        XCTAssertEqual(hits.first?.document.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertNotNil(hits.first?.snippet)
        XCTAssertTrue(hits.first?.snippet?.title?.contains("<b>") == true || hits.first?.snippet?.body?.contains("<b>") == true)
    }

    /*
     범위를 지정하면 해당 scope의 문서만 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_withScope_returnsHitsWithinScopeOnly() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "notice-1", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search", body: "Search release note"),
            makeDocument(id: "guide-1", scope: SearchScope(rawValue: "app.guide"), title: "Swift Search", body: "Search guide")
        ])

        let hits = try searchStore.search(
            SearchQuery(
                text: "swift search",
                scope: SearchScope(rawValue: "app.notice")
            )
        )

        XCTAssertEqual(hits.map(\.document.id), ["notice-1"])
    }

    /*
     limit과 offset이 함께 적용되어 페이지네이션 결과가 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_withLimitAndOffset_returnsPagedHits() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search One", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 10)),
            makeDocument(id: "doc-2", title: "Swift Search Two", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 20)),
            makeDocument(id: "doc-3", title: "Swift Search Three", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 30))
        ])

        let hits = try searchStore.search(
            SearchQuery(
                text: "swift search",
                limit: 1,
                offset: 1
            )
        )

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.document.id, "doc-2")
    }

    /*
     동일 점수 결과는 최신 문서가 먼저 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_withEqualScore_ordersByLastUpdatedAtDescending() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-old", title: "Swift Search", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 1)),
            makeDocument(id: "doc-new", title: "Swift Search", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 2))
        ])

        let hits = try searchStore.search(SearchQuery(text: "swift search"))

        XCTAssertEqual(hits.map(\.document.id), ["doc-new", "doc-old"])
    }

    /*
     일치 문서가 없으면 빈 결과를 반환하는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_withNoMatch_returnsEmptyArray() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index(makeDocument(id: "notice-1", title: "Swift Search", body: "sqlite"))

        let hits = try searchStore.search(SearchQuery(text: "unmatched"))

        XCTAssertTrue(hits.isEmpty)
    }

    /*
     유효하지 않은 질의는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_search_withInvalidQuery_throwsInvalidQuery() throws {
        let storage = try InMemorySQLiteStorage.make()
        let searchStore = SQLiteSearchStore(storage: storage)

        XCTAssertThrowsError(
            try searchStore.search(SearchQuery(text: "   ", limit: 1))
        ) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     keywords 컬럼에만 일치하는 토큰도 검색 결과로 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_matchesKeywordsColumn() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "keyword-only",
                title: "Notice",
                body: "Migration overview",
                keywords: ["swift", "fts"],
                lastUpdatedAt: Date(timeIntervalSince1970: 100)
            )
        ])

        let hits = try searchStore.search(SearchQuery(text: "swift"))

        XCTAssertEqual(hits.map(\.document.id), ["keyword-only"])
    }

    /*
     여러 토큰이 입력되면 모든 토큰이 포함된 문서만 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_requiresAllTokensToMatch() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "match-all",
                title: "Swift SQLite Guide",
                body: "FTS tutorial",
                keywords: ["swift", "sqlite"],
                lastUpdatedAt: Date(timeIntervalSince1970: 100)
            ),
            makeDocument(
                id: "match-partial",
                title: "Swift Guide",
                body: "Only swift appears here",
                keywords: ["swift"],
                lastUpdatedAt: Date(timeIntervalSince1970: 90)
            )
        ])

        let hits = try searchStore.search(SearchQuery(text: "swift sqlite"))

        XCTAssertEqual(hits.map(\.document.id), ["match-all"])
    }

    /*
     offset이 전체 결과 수보다 크면 빈 배열을 반환하는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_search_withOffsetGreaterThanResultCount_returnsEmptyArray() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search", body: "swift sqlite search"),
            makeDocument(id: "doc-2", title: "Swift Search", body: "swift sqlite search")
        ])

        let hits = try searchStore.search(
            SearchQuery(
                text: "swift search",
                limit: 10,
                offset: 10
            )
        )

        XCTAssertTrue(hits.isEmpty)
    }

}

private extension SQLiteSearchStoreTests {
    /*
     테스트용 문서를 생성합니다.

     Parameters:
     - id: 문서 식별자
     - scope: 검색 범위
     - title: 문서 제목
     - body: 문서 본문
     - keywords: 문서 키워드 목록
     - lastUpdatedAt: 문서 갱신 시각

     Returns:
     - 테스트에서 사용할 SearchDocument
     */
    func makeDocument(
        id: String,
        scope: SearchScope = SearchScope(rawValue: "app.notice"),
        title: String = "SearchEngine",
        body: String = "SQLite full text search",
        keywords: [String] = ["swift", "search"],
        lastUpdatedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> SearchDocument {
        SearchDocument(
            id: id,
            scope: scope,
            title: title,
            body: body,
            keywords: keywords,
            lastUpdatedAt: lastUpdatedAt
        )
    }
}
