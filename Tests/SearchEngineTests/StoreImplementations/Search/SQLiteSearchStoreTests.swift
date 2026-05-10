//
//  SQLiteSearchStoreTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SQLiteSearchStore의 검색 실행 동작을 확인하는 테스트입니다.
final class SQLiteSearchStoreTests: XCTestCase {
    func test_search_returnsMatchedHitsWithSnippet() throws {
        // given
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

        // when
        let hits = try searchStore.search(SearchQuery(text: "swift search"))

        // then
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.document.id, "notice-1")
        XCTAssertEqual(hits.first?.document.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertNotNil(hits.first?.snippet)
        XCTAssertTrue(hits.first?.snippet?.title?.contains("<b>") == true || hits.first?.snippet?.body?.contains("<b>") == true)
    }

    func test_search_withScope_returnsHitsWithinScopeOnly() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "notice-1", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search", body: "Search release note"),
            makeDocument(id: "guide-1", scope: SearchScope(rawValue: "app.guide"), title: "Swift Search", body: "Search guide")
        ])

        // when
        let hits = try searchStore.search(
            SearchQuery(
                text: "swift search",
                scope: SearchScope(rawValue: "app.notice")
            )
        )

        // then
        XCTAssertEqual(hits.map(\.document.id), ["notice-1"])
    }

    func test_search_withLimitAndOffset_returnsPagedHits() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search One", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 10)),
            makeDocument(id: "doc-2", title: "Swift Search Two", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 20)),
            makeDocument(id: "doc-3", title: "Swift Search Three", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 30))
        ])

        // when
        let hits = try searchStore.search(
            SearchQuery(
                text: "swift search",
                limit: 1,
                offset: 1
            )
        )

        // then
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.document.id, "doc-2")
    }

    func test_search_withEqualScore_ordersByLastUpdatedAtDescending() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-old", title: "Swift Search", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 1)),
            makeDocument(id: "doc-new", title: "Swift Search", body: "swift sqlite search", lastUpdatedAt: Date(timeIntervalSince1970: 2))
        ])

        // when
        let hits = try searchStore.search(SearchQuery(text: "swift search"))

        // then
        XCTAssertEqual(hits.map(\.document.id), ["doc-new", "doc-old"])
    }

    func test_search_withNoMatch_returnsEmptyArray() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index(makeDocument(id: "notice-1", title: "Swift Search", body: "sqlite"))

        // when
        let hits = try searchStore.search(SearchQuery(text: "unmatched"))

        // then
        XCTAssertTrue(hits.isEmpty)
    }

    func test_search_withInvalidQuery_throwsInvalidQuery() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let searchStore = SQLiteSearchStore(storage: storage)

        // when / then
        XCTAssertThrowsError(
            try searchStore.search(SearchQuery(text: "   ", limit: 1))
        ) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_search_matchesKeywordsColumn() throws {
        // given
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

        // when
        let hits = try searchStore.search(SearchQuery(text: "swift"))

        // then
        XCTAssertEqual(hits.map(\.document.id), ["keyword-only"])
    }

    func test_search_requiresAllTokensToMatch() throws {
        // given
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

        // when
        let hits = try searchStore.search(SearchQuery(text: "swift sqlite"))

        // then
        XCTAssertEqual(hits.map(\.document.id), ["match-all"])
    }

    func test_search_withOffsetGreaterThanResultCount_returnsEmptyArray() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search", body: "swift sqlite search"),
            makeDocument(id: "doc-2", title: "Swift Search", body: "swift sqlite search")
        ])

        // when
        let hits = try searchStore.search(
            SearchQuery(
                text: "swift search",
                limit: 10,
                offset: 10
            )
        )

        // then
        XCTAssertTrue(hits.isEmpty)
    }

}

private extension SQLiteSearchStoreTests {
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
