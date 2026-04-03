//
//  SQLiteDatabaseTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3
import XCTest
@testable import SearchEngine

/*
 SQLiteDatabase의 저수준 SQLite foundation 동작과 에러 매핑을 검증하는 테스트입니다.

 이 테스트는 SQL 공백 입력, statement 준비 실패, 읽기/쓰기 오류 매핑,
 in-memory 연결 문자열, 트랜잭션 롤백 같은 경계를 직접 확인하여
 이후 Storage, Indexing, Querying 계층이 신뢰할 수 있는 실행 기반을 보장합니다.
 */
final class SQLiteDatabaseTests: XCTestCase {
    /*
     테스트에서 발생시키는 의도적인 실패를 표현하는 에러 타입입니다.

     read와 write가 내부 오류를 SearchEngineError로
     올바르게 감싸는지 검증하기 위해 사용합니다.
     */
    private enum TestFailure: Error {
        case expected
    }

    /*
     공백 SQL을 실행하면 statementExecutionFailed가 발생하는지 검증합니다.
     */
    func test_execute_withEmptySQL_throwsStatementExecutionFailed() throws {
        let database = try InMemorySQLiteDatabase.make()

        XCTAssertThrowsError(try database.execute(sql: "   ")) { error in
            guard case let SearchEngineError.statementExecutionFailed(sql, message) = error else {
                return XCTFail("Expected statementExecutionFailed, got \(error)")
            }

            XCTAssertEqual(sql, "   ")
            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     잘못된 SQL statement를 준비하면 statementPreparationFailed가 발생하는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_prepareStatement_withInvalidSQL_throwsStatementPreparationFailed() throws {
        let database = try InMemorySQLiteDatabase.make()

        try database.execute(
            sql: "CREATE TABLE items (id TEXT PRIMARY KEY);"
        )

        XCTAssertThrowsError(
            try database.read { databasePointer in
                _ = try SQLiteDatabase.prepareStatement(
                    sql: "SELECT FROM items",
                    in: databasePointer
                )
            }
        ) { error in
            guard case let SearchEngineError.statementPreparationFailed(sql, message) = error else {
                return XCTFail("Expected statementPreparationFailed, got \(error)")
            }

            XCTAssertEqual(sql, "SELECT FROM items")
            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     읽기 작업 블록이 일반 오류를 던지면 readFailed로 변환되는지 검증합니다.
     */
    func test_read_whenBlockThrows_mapsToReadFailed() throws {
        let database = try InMemorySQLiteDatabase.make()

        do {
            let _: Int = try database.read { _ in
                throw TestFailure.expected
            }
            XCTFail("Expected readFailed error")
        } catch let error as SearchEngineError {
            guard case let .readFailed(message) = error else {
                return XCTFail("Expected readFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     쓰기 작업 블록이 일반 오류를 던지면 writeFailed로 변환되는지 검증합니다.
     */
    func test_write_whenBlockThrows_mapsToWriteFailed() throws {
        let database = try InMemorySQLiteDatabase.make()

        do {
            let _: Int = try database.write { _ in
                throw TestFailure.expected
            }
            XCTFail("Expected writeFailed error")
        } catch let error as SearchEngineError {
            guard case let .writeFailed(message) = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     in-memory 연결 문자열이 shared cache URI 형식으로 생성되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_inMemoryConnectionString_returnsSharedCacheURI() throws {
        let configuration = SearchEngineConfiguration.inMemory(identifier: "Search Engine Test")
        let connectionString = try configuration.inMemoryConnectionString()

        XCTAssertTrue(connectionString.hasPrefix("file:"))
        XCTAssertTrue(connectionString.contains("mode=memory"))
        XCTAssertTrue(connectionString.contains("cache=shared"))
    }

    /*
     동일한 in-memory 식별자를 사용하면 같은 shared cache를 참조하는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_inMemoryDatabase_withSameIdentifier_sharesDatabase() throws {
        let identifier = UUID().uuidString
        let firstDatabase = try InMemorySQLiteDatabase.make(identifier: identifier)
        let secondDatabase = try InMemorySQLiteDatabase.make(identifier: identifier)

        try firstDatabase.execute(
            sql: "CREATE TABLE shared_items (id TEXT PRIMARY KEY);"
        )
        try firstDatabase.execute(
            sql: "INSERT INTO shared_items (id) VALUES ('1');"
        )

        let count = try secondDatabase.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM shared_items;",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }

        XCTAssertEqual(count, 1)
    }


    /*
     foreign key 옵션을 활성화하면 foreign_keys pragma 값이 1로 적용되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_init_withForeignKeysEnabled_setsForeignKeysPragmaToOn() throws {
        let database = try makeDiskDatabase(
            enablesWriteAheadLogging: false,
            enablesForeignKeys: true
        )

        let foreignKeysValue = try database.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "PRAGMA foreign_keys;",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return -1
            }

            return Int(sqlite3_column_int(statement, 0))
        }

        XCTAssertEqual(foreignKeysValue, 1)
    }

    /*
     WAL 옵션을 활성화한 디스크 기반 데이터베이스에서 journal_mode pragma 값이 wal로 적용되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_init_withWriteAheadLoggingEnabled_setsJournalModeToWAL() throws {
        let database = try makeDiskDatabase(
            enablesWriteAheadLogging: true,
            enablesForeignKeys: true
        )

        let journalMode = try database.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "PRAGMA journal_mode;",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW,
                  let cString = sqlite3_column_text(statement, 0) else {
                return ""
            }

            return String(cString: cString)
        }

        XCTAssertEqual(journalMode.lowercased(), "wal")
    }
}

private extension SQLiteDatabaseTests {
    /*
     pragma 동작 검증용 디스크 기반 SQLiteDatabase를 생성합니다.

     WAL journal_mode는 in-memory 연결에서 기대값이 달라질 수 있으므로,
     디스크 기반 임시 경로를 사용해 실제 운영 경로와 가까운 조건에서 확인합니다.

     Parameters:
     - enablesWriteAheadLogging: WAL 모드 사용 여부
     - enablesForeignKeys: foreign key 사용 여부

     Returns:
     - 지정한 설정으로 초기화된 SQLiteDatabase

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func makeDiskDatabase(
        enablesWriteAheadLogging: Bool,
        enablesForeignKeys: Bool
    ) throws -> SQLiteDatabase {
        let temporaryBaseDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let configuration = try SearchEngineConfiguration.live(
            directoryName: "SearchEngine",
            fileName: "SearchEngine.sqlite",
            baseDirectoryURL: temporaryBaseDirectoryURL,
            enablesWriteAheadLogging: enablesWriteAheadLogging,
            enablesForeignKeys: enablesForeignKeys
        )

        addTeardownBlock {
            try? FileManager.default.removeItem(at: temporaryBaseDirectoryURL)
        }

        return try SQLiteDatabase(configuration: configuration)
    }
}
