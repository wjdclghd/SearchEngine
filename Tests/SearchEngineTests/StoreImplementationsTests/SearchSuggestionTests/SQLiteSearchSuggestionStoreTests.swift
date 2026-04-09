//
//  SQLiteSearchSuggestionStoreTests.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SQLiteSearchSuggestionStore의 제안 생성 동작을 확인하는 테스트입니다.

 Suggest Store는 입력 문자열 검증, prefix 기반 FTS 후보 조회,
 제목 단위 중복 제거, 정렬 우선순위와 범위 제한을 함께 처리합니다.
 이 테스트는 실제 in-memory SQLite 저장소 위에서 제안 목록이 기대 규칙대로 생성되는지 검증합니다.
 */
final class SQLiteSearchSuggestionStoreTests: XCTestCase {
    /*
     입력 문자열과 일치하는 제목 제안이 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_suggest_returnsTitleBasedSuggestions() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "notice-1",
                scope: SearchScope(rawValue: "app.notice"),
                title: "Swift Search Engine",
                body: "SQLite FTS5 powers search suggestions",
                keywords: ["swift", "search"]
            ),
            makeDocument(
                id: "notice-2",
                scope: SearchScope(rawValue: "app.notice"),
                title: "Persistence Guide",
                body: "Core Data migration overview",
                keywords: ["coredata"]
            )
        ])

        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "swift se")
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.text, "Swift Search Engine")
        XCTAssertEqual(suggestions.first?.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertGreaterThan(suggestions.first?.score ?? 0, 0)
    }

    /*
     범위를 지정하면 해당 scope의 제안만 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_suggest_withScope_returnsSuggestionsWithinScopeOnly() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "notice-1", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search Notice", body: "Search release note"),
            makeDocument(id: "guide-1", scope: SearchScope(rawValue: "app.guide"), title: "Swift Search Guide", body: "Search guide")
        ])

        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(
                text: "swift search",
                scope: SearchScope(rawValue: "app.notice")
            )
        )

        XCTAssertEqual(suggestions.map(\.text), ["Swift Search Notice"])
        XCTAssertEqual(suggestions.map(\.scope), [SearchScope(rawValue: "app.notice")])
    }

    /*
     동일한 제목과 범위 조합은 하나의 제안으로 중복 제거되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_suggest_deduplicatesSameTitleWithinSameScope() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search", body: "swift search first", lastUpdatedAt: Date(timeIntervalSince1970: 10)),
            makeDocument(id: "doc-2", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search", body: "swift search second", lastUpdatedAt: Date(timeIntervalSince1970: 20))
        ])

        let suggestions = try suggestionStore.suggest(SearchSuggestionQuery(text: "swift se"))

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.text, "Swift Search")
        XCTAssertEqual(suggestions.first?.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertGreaterThanOrEqual(suggestions.first?.score ?? 0, 120)
    }

    /*
     exact title match가 contains match보다 먼저 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_suggest_prioritizesExactMatchBeforeContainsMatch() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search", body: "swift search"),
            makeDocument(id: "doc-2", title: "Guide for Swift Search", body: "swift search")
        ])

        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "Swift Search")
        )

        XCTAssertEqual(suggestions.map(\.text), ["Swift Search", "Guide for Swift Search"])
    }

    /*
     title prefix match가 contains match보다 먼저 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_suggest_prioritizesPrefixTitleMatchBeforeContainsMatch() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search Engine", body: "swift search"),
            makeDocument(id: "doc-2", title: "Guide for Swift Search", body: "swift search")
        ])

        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "Swift Sea")
        )

        XCTAssertEqual(
            suggestions.map(\.text),
            ["Swift Search Engine", "Guide for Swift Search"]
        )
    }

    /*
     limit이 적용되어 지정한 개수만큼만 반환되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_suggest_withLimit_returnsLimitedSuggestions() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search One", body: "swift search"),
            makeDocument(id: "doc-2", title: "Swift Search Two", body: "swift search"),
            makeDocument(id: "doc-3", title: "Swift Search Three", body: "swift search")
        ])

        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(
                text: "swift search",
                limit: 2
            )
        )

        XCTAssertEqual(suggestions.count, 2)
    }

    /*
     keywords에만 일치하고 title에는 일치하지 않으면 제안되지 않는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_suggest_doesNotReturnSuggestionWhenOnlyKeywordsMatch() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "keyword-only",
                title: "Notice",
                body: "Migration overview",
                keywords: ["swift", "fts"],
                lastUpdatedAt: Date(timeIntervalSince1970: 100)
            )
        ])

        let suggestions = try suggestionStore.suggest(SearchSuggestionQuery(text: "swift"))

        XCTAssertTrue(suggestions.isEmpty)
    }

    /*
     유효하지 않은 질의는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_suggest_withInvalidQuery_throwsInvalidQuery() throws {
        let storage = try InMemorySQLiteStorage.make()
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        XCTAssertThrowsError(
            try suggestionStore.suggest(SearchSuggestionQuery(text: "   ", limit: 1))
        ) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }
}

private extension SQLiteSearchSuggestionStoreTests {
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
