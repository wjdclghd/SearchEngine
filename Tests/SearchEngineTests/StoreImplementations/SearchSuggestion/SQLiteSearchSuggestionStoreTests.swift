//
//  SQLiteSearchSuggestionStoreTests.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SQLiteSearchSuggestionStore의 제안 생성 동작을 확인하는 테스트입니다.
final class SQLiteSearchSuggestionStoreTests: XCTestCase {
    func test_suggest_returnsTitleBasedSuggestions() throws {
        // given
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

        // when
        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "swift se")
        )

        // then
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.text, "Swift Search Engine")
        XCTAssertEqual(suggestions.first?.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertEqual(suggestions.first?.source, .title)
        XCTAssertEqual(suggestions.first?.kind, .document)
        XCTAssertEqual(suggestions.first?.documentID, "notice-1")
        XCTAssertEqual(suggestions.first?.matchedText, "swift se")
        XCTAssertGreaterThan(suggestions.first?.score ?? 0, 0)
    }

    func test_suggest_withScope_returnsSuggestionsWithinScopeOnly() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "notice-1", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search Notice", body: "Search release note"),
            makeDocument(id: "guide-1", scope: SearchScope(rawValue: "app.guide"), title: "Swift Search Guide", body: "Search guide")
        ])

        // when
        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(
                text: "swift search",
                scope: SearchScope(rawValue: "app.notice")
            )
        )

        // then
        XCTAssertEqual(suggestions.map(\.text), ["Swift Search Notice"])
        XCTAssertEqual(suggestions.map(\.scope), [SearchScope(rawValue: "app.notice")])
    }

    func test_suggest_deduplicatesSameTitleWithinSameScope() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search", body: "swift search first", lastUpdatedAt: Date(timeIntervalSince1970: 10)),
            makeDocument(id: "doc-2", scope: SearchScope(rawValue: "app.notice"), title: "Swift Search", body: "swift search second", lastUpdatedAt: Date(timeIntervalSince1970: 20))
        ])

        // when
        let suggestions = try suggestionStore.suggest(SearchSuggestionQuery(text: "swift se"))

        // then
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.text, "Swift Search")
        XCTAssertEqual(suggestions.first?.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertGreaterThanOrEqual(suggestions.first?.score ?? 0, 120)
    }

    func test_suggest_prioritizesExactMatchBeforeContainsMatch() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search", body: "swift search"),
            makeDocument(id: "doc-2", title: "Guide for Swift Search", body: "swift search")
        ])

        // when
        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "Swift Search")
        )

        // then
        XCTAssertEqual(suggestions.map(\.text), ["Swift Search", "Guide for Swift Search"])
    }

    func test_suggest_prioritizesPrefixTitleMatchBeforeContainsMatch() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search Engine", body: "swift search"),
            makeDocument(id: "doc-2", title: "Guide for Swift Search", body: "swift search")
        ])

        // when
        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "Swift Sea")
        )

        // then
        XCTAssertEqual(
            suggestions.map(\.text),
            ["Swift Search Engine", "Guide for Swift Search"]
        )
    }

    func test_suggest_withLimit_returnsLimitedSuggestions() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "doc-1", title: "Swift Search One", body: "swift search"),
            makeDocument(id: "doc-2", title: "Swift Search Two", body: "swift search"),
            makeDocument(id: "doc-3", title: "Swift Search Three", body: "swift search")
        ])

        // when
        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(
                text: "swift search",
                limit: 2
            )
        )

        // then
        XCTAssertEqual(suggestions.count, 2)
    }

    func test_suggest_returnsSuggestionWhenKeywordsMatch() throws {
        // given
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

        // when
        let suggestions = try suggestionStore.suggest(SearchSuggestionQuery(text: "swift"))

        // then
        XCTAssertEqual(suggestions.map(\.text), ["Notice"])
        XCTAssertEqual(suggestions.first?.source, .keyword)
        XCTAssertEqual(suggestions.first?.kind, .document)
        XCTAssertEqual(suggestions.first?.documentID, "keyword-only")
        XCTAssertEqual(suggestions.first?.matchedText, "swift")
    }

    func test_suggest_returnsSuggestionWhenBodyMatches() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "body-only",
                title: "Calendar",
                body: "lunar schedule app",
                keywords: ["date"],
                lastUpdatedAt: Date(timeIntervalSince1970: 100)
            )
        ])

        // when
        let suggestions = try suggestionStore.suggest(SearchSuggestionQuery(text: "lunar"))

        // then
        XCTAssertEqual(suggestions.map(\.text), ["Calendar"])
        XCTAssertEqual(suggestions.first?.source, .body)
        XCTAssertEqual(suggestions.first?.kind, .document)
        XCTAssertEqual(suggestions.first?.documentID, "body-only")
        XCTAssertEqual(suggestions.first?.matchedText, "lunar")
    }

    func test_suggest_withSingleKoreanCharacter_returnsAppStoreSuggestions() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        try documentStore.index([
            makeDocument(id: "music", title: "음악", body: "음악 스트리밍", keywords: ["music"], lastUpdatedAt: Date(timeIntervalSince1970: 300)),
            makeDocument(id: "voice-recorder", title: "음성녹음", body: "녹음 앱", keywords: ["record"], lastUpdatedAt: Date(timeIntervalSince1970: 200)),
            makeDocument(id: "lunar-calendar", title: "음력달력", body: "달력 앱", keywords: ["calendar"], lastUpdatedAt: Date(timeIntervalSince1970: 100)),
            makeDocument(id: "photo-editor", title: "사진편집", body: "이미지 편집", keywords: ["photo"])
        ])

        // when
        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "음", limit: 5)
        )

        // then
        XCTAssertEqual(suggestions.map(\.text), ["음악", "음성녹음", "음력달력"])
        XCTAssertTrue(suggestions.allSatisfy { $0.source == .title })
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .document })
    }

    func test_suggest_withInvalidQuery_throwsInvalidQuery() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let suggestionStore = SQLiteSearchSuggestionStore(storage: storage)

        // when / then
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
