//
//  SearchRebuilderTests.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation
import SQLite3
import XCTest
@testable import SearchEngine

/// SearchRebuilder의 FTS projection 재구성 동작을 확인하는 테스트입니다.
final class SearchRebuilderTests: XCTestCase {
    func test_rebuild_restoresProjectionFromDocumentsTable() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "notice-1",
                title: "Swift Search",
                body: "Projection restore",
                keywords: ["swift", "search"]
            ),
            makeDocument(
                id: "notice-2",
                title: "SQLite Guide",
                body: "Projection restore",
                keywords: ["sqlite", "guide"]
            )
        ])
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            0
        )

        // when
        try rebuilder.rebuild()

        // then
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage),
            2
        )
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            2
        )
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "swift")).map(\.document.title),
            ["Swift Search"]
        )
    }

    func test_rebuild_replacesCorruptedProjectionWithDocumentProjection() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index(
            makeDocument(
                id: "notice-1",
                title: "Swift Search",
                body: "Original body",
                keywords: ["swift", "search"]
            )
        )
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )
        try storage.execute(
            sql: """
            INSERT INTO \(SearchEngineMigrationSQL.documentsFTSTableName) (
                id, scope, title, body, keywords
            ) VALUES (
                'notice-1',
                'app.notice',
                'Broken Projection',
                'Broken body',
                'broken'
            );
            """
        )
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "broken")).map(\.document.title),
            ["Swift Search"]
        )

        // when
        try rebuilder.rebuild()

        // then
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "swift")).map(\.document.title),
            ["Swift Search"]
        )
        XCTAssertTrue(
            try searchStore.search(SearchQuery(text: "broken")).isEmpty
        )
    }

    func test_rebuild_withNoDocuments_clearsProjectionTable() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let rebuilder = SearchRebuilder(storage: storage)

        try storage.execute(
            sql: """
            INSERT INTO \(SearchEngineMigrationSQL.documentsFTSTableName) (
                id, scope, title, body, keywords
            ) VALUES (
                'orphan-1',
                'app.notice',
                'Orphan Projection',
                'Orphan body',
                'orphan'
            );
            """
        )
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            1
        )

        // when
        try rebuilder.rebuild()

        // then
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage),
            0
        )
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            0
        )
    }

    func test_rebuild_preservesScopedSearchResult() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "guide-1",
                scope: SearchScope(rawValue: "app.guide"),
                title: "Swift Search",
                body: "Guide scope",
                keywords: ["swift", "guide"]
            ),
            makeDocument(
                id: "notice-1",
                scope: SearchScope(rawValue: "app.notice"),
                title: "Swift Intro",
                body: "Notice scope",
                keywords: ["swift", "notice"]
            )
        ])
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )

        // when
        try rebuilder.rebuild()

        // then
        XCTAssertEqual(
            try searchStore.search(
                SearchQuery(
                    text: "swift",
                    scope: SearchScope(rawValue: "app.guide")
                )
            ).map(\.document.title),
            ["Swift Search"]
        )
    }

    func test_rebuild_preservesSearchTargetsAcrossTitleBodyAndKeywords() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index(
            makeDocument(
                id: "notice-1",
                title: "Swift Search",
                body: "Projection restore body",
                keywords: ["fts", "index"]
            )
        )
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )

        // when
        try rebuilder.rebuild()

        // then
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "swift")).map(\.document.title),
            ["Swift Search"]
        )
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "projection")).map(\.document.title),
            ["Swift Search"]
        )
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "fts")).map(\.document.title),
            ["Swift Search"]
        )
    }
}

private extension SearchRebuilderTests {
    func makeDocument(
        id: String,
        scope: SearchScope = SearchScope(rawValue: "app.notice"),
        title: String = "Search Engine",
        body: String = "SQLite FTS5 Indexing",
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

    func fetchRowCount(
        in tableName: String,
        using storage: SQLiteStorageProtocol
    ) throws -> Int {
        try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM \(tableName);",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }
    }
}
