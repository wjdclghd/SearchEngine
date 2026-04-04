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

/*
 SQLiteSearchDocumentStore의 문서 저장과 삭제 동작을 확인하는 테스트입니다.

 Store 구현체는 일반 문서 테이블과 FTS projection을 함께 갱신하므로,
 단순 저장 성공 여부보다 트랜잭션 일관성과 projection 동기화가 더 중요합니다.
 이 테스트는 단건/다건 저장, 교체 저장, 삭제, 롤백 경계까지 함께 검증합니다.
 */
final class SQLiteSearchDocumentStoreTests: XCTestCase {
    /*
     문서 한 건을 저장하면 원본 테이블과 FTS projection이 함께 저장되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_index_singleDocument_persistsDocumentAndFTSProjection() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let document = makeDocument(
            id: "notice-1",
            scope: SearchScope(rawValue: " app.notice "),
            title: "SearchEngine Indexing",
            body: "SQLite FTS5 document indexing",
            keywords: ["swift", "fts5"]
        )

        try documentStore.index(document)

        let storedManagedObject = try fetchManagedObject(
            id: "notice-1",
            using: storage
        )
        let ftsCount = try fetchFTSRowCount(
            id: "notice-1",
            using: storage
        )

        XCTAssertEqual(storedManagedObject?.scope, "app.notice")
        XCTAssertEqual(storedManagedObject?.title, "SearchEngine Indexing")
        XCTAssertEqual(storedManagedObject?.body, "SQLite FTS5 document indexing")
        XCTAssertEqual(storedManagedObject?.keywords, "swift\nfts5")
        XCTAssertEqual(ftsCount, 1)
    }

    /*
     문서 여러 건을 저장하면 모든 projection이 함께 저장되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_index_multipleDocuments_persistsAllDocuments() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let documents = [
            makeDocument(id: "notice-1", title: "First", body: "One"),
            makeDocument(id: "notice-2", title: "Second", body: "Two")
        ]

        try documentStore.index(documents)

        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 2)
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage), 2)
    }

    /*
     같은 id의 문서를 다시 저장하면 기존 저장 projection이 교체되고 FTS row 수가 유지되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_index_withExistingDocument_replacesStoredProjection() throws {
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
        try documentStore.index(
            makeDocument(
                id: "notice-1",
                title: "New Title",
                body: "New Body",
                keywords: ["new", "fts"],
                lastUpdatedAt: Date(timeIntervalSince1970: 2)
            )
        )

        let storedManagedObject = try fetchManagedObject(id: "notice-1", using: storage)

        XCTAssertEqual(storedManagedObject?.title, "New Title")
        XCTAssertEqual(storedManagedObject?.body, "New Body")
        XCTAssertEqual(storedManagedObject?.keywords, "new\nfts")
        
        let lastUpdatedAt = try XCTUnwrap(storedManagedObject?.lastUpdatedAt)
        XCTAssertEqual(lastUpdatedAt, 2, accuracy: 0.0001)
        
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 1)
        XCTAssertEqual(try fetchFTSRowCount(id: "notice-1", using: storage), 1)
    }

    /*
     문서를 삭제하면 원본 테이블과 FTS projection에서 함께 제거되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_deleteDocument_removesDocumentAndFTSProjection() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)

        try documentStore.index(makeDocument(id: "notice-1"))
        try documentStore.deleteDocument(id: "notice-1")

        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 0)
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage), 0)
    }

    /*
     빈 식별자로 삭제를 요청하면 invalidDocument를 반환하는지 검증합니다.
     */
    func test_deleteDocument_withEmptyIdentifier_throwsInvalidDocument() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)

        XCTAssertThrowsError(try documentStore.deleteDocument(id: "   ")) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     유효하지 않은 문서를 저장하면 invalidDocument를 반환하고 저장이 발생하지 않는지 검증합니다.
     */
    func test_index_withInvalidDocument_throwsInvalidDocumentAndDoesNotWrite() throws {
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

        XCTAssertThrowsError(try documentStore.index(invalidDocument)) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }

        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage), 0)
        XCTAssertEqual(try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage), 0)
    }

    /*
     FTS projection 준비에 실패하면 전체 저장 트랜잭션이 rollback 되는지 검증합니다.

     일반 문서 테이블만 존재하는 상태에서 저장을 시도해 FTS 준비를 실패시키고,
     앞서 저장된 원본 row가 남지 않는지 확인합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_index_whenFTSProjectionPreparationFails_rollsBackTransaction() throws {
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
    /*
     테스트용 SearchDocument를 생성합니다.

     Parameters:
     - id: 문서 식별자
     - scope: 문서 범위
     - title: 문서 제목
     - body: 문서 본문
     - keywords: 문서 키워드 목록
     - lastUpdatedAt: 문서 갱신 시각

     Returns:
     - 테스트에 사용할 SearchDocument
     */
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

    /*
     지정한 문서 식별자의 ManagedObject를 조회합니다.

     Parameters:
     - id: 조회할 문서 식별자
     - storage: 조회에 사용할 SQLite 저장 foundation

     Returns:
     - 조회된 SearchDocumentMO 또는 nil

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchManagedObject(
        id: String,
        using storage: SQLiteStorageProtocol
    ) throws -> SearchDocumentMO? {
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

            return SearchDocumentMO(
                id: stringValue(from: statement, index: 0),
                scope: stringValue(from: statement, index: 1),
                title: stringValue(from: statement, index: 2),
                body: stringValue(from: statement, index: 3),
                keywords: stringValue(from: statement, index: 4),
                lastUpdatedAt: sqlite3_column_double(statement, 5)
            )
        }
    }

    /*
     지정한 테이블의 전체 row 수를 조회합니다.

     Parameters:
     - tableName: row 수를 조회할 테이블 이름
     - storage: 조회에 사용할 SQLite 저장 foundation

     Returns:
     - 테이블 전체 row 수

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
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

    /*
     지정한 문서 식별자의 FTS projection row 수를 조회합니다.

     Parameters:
     - id: 조회할 문서 식별자
     - storage: 조회에 사용할 SQLite 저장 foundation

     Returns:
     - 해당 문서 식별자에 매핑된 FTS row 수

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
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

    /*
     테스트 조회용 문자열 parameter를 SQLite statement에 바인딩합니다.

     Parameters:
     - value: 바인딩할 문자열 값
     - statement: SQLite statement
     - index: parameter 인덱스

     Throws:
     - 바인딩에 실패하면 에러를 던집니다.
     */
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

    /*
     SQLite row의 문자열 컬럼 값을 반환합니다.

     Parameters:
     - statement: 값을 읽을 SQLite statement
     - index: 문자열 컬럼 인덱스

     Returns:
     - 지정한 컬럼의 문자열 값
     */
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
