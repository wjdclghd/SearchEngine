//
//  SQLiteSearchDocumentStoreTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3
import XCTest
@testable import SearchEngine

/// SQLiteSearchDocumentStore의 문서 저장과 삭제 동작을 확인하는 테스트입니다.
final class SQLiteSearchDocumentStoreTests: XCTestCase {
    func test_index_singleDocument_persistsDocumentAndFTSProjection() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let document = makeDocument(
            id: "notice-1",
            scope: SearchScope(rawValue: " app.notice "),
            title: "SearchEngine Indexing",
            body: "SQLite FTS5 document indexing",
            keywords: ["swift", "fts5"]
        )

        // when
        try documentStore.index(document)

        let storedRecord = try fetchRecord(
            id: "notice-1",
            using: storage
        )
        let ftsCount = try fetchFTSRowCount(
            id: "notice-1",
            using: storage
        )

        // then
        XCTAssertEqual(storedRecord?.scope, "app.notice")
        XCTAssertEqual(storedRecord?.title, "SearchEngine Indexing")
        XCTAssertEqual(storedRecord?.body, "SQLite FTS5 document indexing")
        XCTAssertEqual(storedRecord?.keywords, "swift\nfts5")
        XCTAssertEqual(ftsCount, 1)
    }

    func test_index_multipleDocuments_persistsAllDocuments() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let documents = [
            makeDocument(id: "notice-1", title: "First", body: "One"),
            makeDocument(id: "notice-2", title: "Second", body: "Two")
        ]

        // when
        try documentStore.index(documents)

        // then
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 2)
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage), 2)
    }

    func test_index_withExistingDocument_replacesStoredProjection() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)

        try documentStore.index(
            makeDocument(
                id: "notice-1",
                title: "Old Title",
                body: "Old Body",
                keywords: ["old"],
                lastUpdatedAt: Date(timeIntervalSince1970: 1)
            )
        )

        // when
        try documentStore.index(
            makeDocument(
                id: "notice-1",
                title: "New Title",
                body: "New Body",
                keywords: ["new", "fts"],
                lastUpdatedAt: Date(timeIntervalSince1970: 2)
            )
        )

        let storedRecord = try fetchRecord(id: "notice-1", using: storage)

        // then
        XCTAssertEqual(storedRecord?.title, "New Title")
        XCTAssertEqual(storedRecord?.body, "New Body")
        XCTAssertEqual(storedRecord?.keywords, "new\nfts")

        let lastUpdatedAt = try XCTUnwrap(storedRecord?.lastUpdatedAt)
        XCTAssertEqual(lastUpdatedAt, 2, accuracy: 0.0001)

        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 1)
        XCTAssertEqual(try fetchFTSRowCount(id: "notice-1", using: storage), 1)
    }

    func test_deleteDocument_removesDocumentAndFTSProjection() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)

        try documentStore.index(makeDocument(id: "notice-1"))

        // when
        try documentStore.deleteDocument(id: "notice-1")

        // then
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 0)
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage), 0)
    }

    func test_deleteDocument_withEmptyIdentifier_throwsInvalidDocument() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)

        // when / then
        XCTAssertThrowsError(try documentStore.deleteDocument(id: "   ")) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_index_withInvalidDocument_throwsInvalidDocumentAndDoesNotWrite() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let invalidDocument = SearchDocument(
            id: "notice-1",
            scope: SearchScope(rawValue: "notice"),
            title: "   ",
            body: "   ",
            keywords: [],
            lastUpdatedAt: Date(timeIntervalSince1970: 10)
        )

        // when / then
        XCTAssertThrowsError(try documentStore.index(invalidDocument)) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }

        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 0)
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage), 0)
    }

    func test_index_whenFTSProjectionPreparationFails_rollsBackTransaction() throws {
        // given
        let partialMigrationPlan = SearchEngineMigrationPlan(
            migrations: SearchEngineMigrationPlan.sqliteCore.migrations + [
                .init(
                    version: 2,
                    statements: [
                        SearchEngineMigrationSQL.createDocumentsTable,
                        SearchEngineMigrationSQL.createDocumentsScopeUpdatedAtIndex
                    ]
                )
            ]
        )
        let storage = try SQLiteStorage(
            configuration: .inMemory(
                identifier: UUID().uuidString,
                migrationPlan: partialMigrationPlan,
                enablesWriteAheadLogging: false,
                enablesForeignKeys: true
            )
        )
        let documentStore = SQLiteSearchDocumentStore(storage: storage)

        // when / then
        XCTAssertThrowsError(try documentStore.index(makeDocument(id: "notice-1"))) { error in
            switch error {
            case let SearchEngineError.statementPreparationFailed(sql, message):
                XCTAssertTrue(sql.contains(SearchEngineMigrationSQL.documentsFTSTableName))
                XCTAssertFalse(message.isEmpty)

            case let SearchEngineError.statementExecutionFailed(sql, message):
                XCTAssertTrue(sql.contains(SearchEngineMigrationSQL.documentsFTSTableName))
                XCTAssertFalse(message.isEmpty)

            default:
                XCTFail("Expected SQLite statement failure, got \(error)")
            }
        }

        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 0)
    }
}

private extension SQLiteSearchDocumentStoreTests {
    func makeDocument(
        id: String,
        scope: SearchScope = SearchScope(rawValue: "notice"),
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

    func fetchRecord(
        id: String,
        using storage: SQLiteStorageProtocol
    ) throws -> SearchDocumentRecord? {
        try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: """
                SELECT id, scope, title, body, keywords, last_updated_at
                FROM \(SearchEngineMigrationSQL.documentsTableName)
                WHERE id = ?;
                """,
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            try bindText(id, to: statement, index: 1)

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            return SearchDocumentRecord(
                id: stringValue(from: statement, index: 0),
                scope: stringValue(from: statement, index: 1),
                title: stringValue(from: statement, index: 2),
                body: stringValue(from: statement, index: 3),
                keywords: stringValue(from: statement, index: 4),
                lastUpdatedAt: sqlite3_column_double(statement, 5)
            )
        }
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

    func fetchFTSRowCount(
        id: String,
        using storage: SQLiteStorageProtocol
    ) throws -> Int {
        try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM \(SearchEngineMigrationSQL.documentsFTSTableName) WHERE id = ?;",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            try bindText(id, to: statement, index: 1)

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }
    }

    func bindText(
        _ value: String,
        to statement: OpaquePointer,
        index: Int32
    ) throws {
        let result = value.withCString { cString in
            sqlite3_bind_text(
                statement,
                index,
                cString,
                -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
        }

        guard result == SQLITE_OK else {
            throw SearchEngineError.statementBindingFailed(
                index: index,
                message: "Failed to bind test text parameter."
            )
        }
    }

    func stringValue(
        from statement: OpaquePointer,
        index: Int32
    ) -> String {
        guard let cString = sqlite3_column_text(statement, index) else {
            return ""
        }

        return String(cString: cString)
    }
}
