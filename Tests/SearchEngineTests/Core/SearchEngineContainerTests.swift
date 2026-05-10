//
//  SearchEngineContainerTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3
import XCTest
@testable import SearchEngine

/// SearchEngineContainer의 기본 조립 동작을 확인하는 테스트입니다.
final class SearchEngineContainerTests: XCTestCase {
    func test_makeDefaultInMemory_createsContainer() throws {
        // given / when
        let container = try SearchEngineContainer.makeDefaultInMemory()

        // then
        guard case .inMemory = container.configuration.storage else {
            return XCTFail("Expected in-memory storage")
        }
    }

    func test_makeSQLiteStorage_returnsUsableStorage() throws {
        // given
        let container = try SearchEngineContainer.makeDefaultInMemory()
        let storage = container.makeSQLiteStorage()

        // when
        try storage.execute(
            sql: "CREATE TABLE metadata (id TEXT PRIMARY KEY);"
        )

        let count = try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE name = 'metadata';",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }

        // then
        XCTAssertEqual(count, 1)
    }

    func test_makeDefault_usesDefaultLivePath() throws {
        // given
        let applicationSupportURL = try XCTUnwrap(
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        )
        let expectedDirectoryURL = applicationSupportURL
            .appendingPathComponent(SearchEngineConfiguration.defaultDirectoryName, isDirectory: true)
        let expectedDatabaseURL = expectedDirectoryURL
            .appendingPathComponent(SearchEngineConfiguration.defaultFileName, isDirectory: false)
        let fileExistedBeforeTest = FileManager.default.fileExists(atPath: expectedDatabaseURL.path)

        defer {
            if fileExistedBeforeTest == false {
                try? FileManager.default.removeItem(at: expectedDatabaseURL)
                try? FileManager.default.removeItem(at: expectedDirectoryURL)
            }
        }

        // when
        let container = try SearchEngineContainer.makeDefault()
        let storage = container.makeSQLiteStorage()
        let tableName = "metadata_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"

        try storage.execute(
            sql: "CREATE TABLE \(tableName) (id TEXT PRIMARY KEY);"
        )

        guard case let .sqlite(directoryName, fileName, baseDirectoryURL) = container.configuration.storage else {
            return XCTFail("Expected sqlite storage")
        }

        // then
        XCTAssertEqual(directoryName, SearchEngineConfiguration.defaultDirectoryName)
        XCTAssertEqual(fileName, SearchEngineConfiguration.defaultFileName)
        XCTAssertNil(baseDirectoryURL)
        XCTAssertEqual(try container.configuration.databaseURL(), expectedDatabaseURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDirectoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDatabaseURL.path))
    }

    func test_make_withInvalidConfiguration_throwsInvalidConfiguration() {
        // given / when
        let configuration = SearchEngineConfiguration.inMemory(identifier: "   ")

        // then
        XCTAssertThrowsError(try SearchEngineContainer.make(configuration: configuration)) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_makeSQLiteSearchDocumentStore_returnsUsableStore() throws {
        // given
        let container = try SearchEngineContainer.makeDefaultInMemory()
        let documentStore = container.makeSQLiteSearchDocumentStore()

        // when
        try documentStore.index(
            SearchDocument(
                id: "notice-1",
                scope: SearchScope(rawValue: "notice"),
                title: "SearchEngine",
                body: "SQLite document store",
                keywords: ["swift", "sqlite"],
                lastUpdatedAt: Date(timeIntervalSince1970: 1)
            )
        )

        let rowCount = try container.makeSQLiteStorage().read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM \(SearchEngineMigrationSQL.documentsTableName);",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }

        // then
        XCTAssertEqual(rowCount, 1)
    }

    func test_makeSQLiteSearchSuggestionStore_returnsUsableStore() throws {
        // given
        let container = try SearchEngineContainer.makeDefaultInMemory()
        let documentStore = container.makeSQLiteSearchDocumentStore()
        let suggestionStore = container.makeSQLiteSearchSuggestionStore()

        try documentStore.index(
            SearchDocument(
                id: "notice-1",
                scope: SearchScope(rawValue: "notice"),
                title: "Swift Search",
                body: "SQLite suggestion store",
                keywords: ["swift", "sqlite"],
                lastUpdatedAt: Date(timeIntervalSince1970: 1)
            )
        )

        // when
        let suggestions = try suggestionStore.suggest(
            SearchSuggestionQuery(text: "swift")
        )

        // then
        XCTAssertEqual(suggestions.map(\.text), ["Swift Search"])
    }

    func test_makeSearchEngine_returnsUsablePublicEngine() async throws {
        // given
        let container = try SearchEngineContainer.makeDefaultInMemory()
        let searchEngine = container.makeSearchEngine()

        try await searchEngine.index(
            SearchDocument(
                id: "appstore.track.1",
                scope: SearchScope(rawValue: "appstore.autocomplete"),
                title: "음악",
                body: "음악 스트리밍 앱",
                keywords: ["music", "streaming"],
                lastUpdatedAt: Date(timeIntervalSince1970: 1)
            )
        )

        // when
        let suggestions = try await searchEngine.suggest(
            SearchSuggestionQuery(text: "음")
        )
        let hits = try await searchEngine.search(
            SearchQuery(text: "streaming")
        )

        // then
        XCTAssertEqual(suggestions.map(\.text), ["음악"])
        XCTAssertEqual(suggestions.first?.documentID, "appstore.track.1")
        XCTAssertEqual(hits.map(\.document.id), ["appstore.track.1"])
    }

    func test_makeSearchRebuilder_returnsUsableRebuilder() throws {
        // given
        let container = try SearchEngineContainer.makeDefaultInMemory()
        let documentStore = container.makeSQLiteSearchDocumentStore()
        let rebuilder = container.makeSearchRebuilder()
        let searchStore = container.makeSQLiteSearchStore()

        try documentStore.index(
            SearchDocument(
                id: "notice-1",
                scope: SearchScope(rawValue: "notice"),
                title: "Swift Search",
                body: "SQLite rebuild",
                keywords: ["swift", "sqlite"],
                lastUpdatedAt: Date(timeIntervalSince1970: 1)
            )
        )
        try container.makeSQLiteStorage().execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )

        // when
        try rebuilder.rebuild()

        // then
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "swift")).map(\.document.title),
            ["Swift Search"]
        )
    }
}
