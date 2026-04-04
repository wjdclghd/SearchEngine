//
//  SQLiteStorageTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3
import XCTest
@testable import SearchEngine

/*
 SQLiteStorage의 기본 읽기/쓰기 및 트랜잭션 동작을 검증하는 테스트입니다.

 아직 실제 검색 엔진 구현이 없으므로,
 저장 foundation이 안전한 SQL 실행과 트랜잭션 롤백을 제공하는지 먼저 확인해두어야
 Indexing, Querying 계층이 같은 기반을 신뢰하고 확장할 수 있습니다.
 */
final class SQLiteStorageTests: XCTestCase {
    /*
     간단한 테이블을 만들고 데이터 삽입 후 다시 읽을 수 있는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_execute_readAndWrite_succeeds() throws {
        let storage = try InMemorySQLiteStorage.make()

        try storage.execute(
            sql: """
            CREATE TABLE items (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL
            );
            """
        )

        try storage.write { databasePointer in
            guard sqlite3_exec(
                databasePointer,
                "INSERT INTO items (id, title) VALUES ('1', 'SwiftUI');",
                nil,
                nil,
                nil
            ) == SQLITE_OK else {
                throw SearchEngineError.statementExecutionFailed(
                    sql: "INSERT INTO items (id, title) VALUES ('1', 'SwiftUI');",
                    message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                )
            }
        }

        let title = try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT title FROM items WHERE id = '1';",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW,
                  let cString = sqlite3_column_text(statement, 0) else {
                return ""
            }

            return String(cString: cString)
        }

        XCTAssertEqual(title, "SwiftUI")
    }

    /*
     잘못된 SQL을 실행하면 statementExecutionFailed가 발생하는지 검증합니다.
     */
    func test_execute_withInvalidSQL_throwsStatementExecutionFailed() throws {
        let storage = try InMemorySQLiteStorage.make()

        XCTAssertThrowsError(try storage.execute(sql: "INVALID SQL")) { error in
            guard case let SearchEngineError.statementExecutionFailed(sql, message) = error else {
                return XCTFail("Expected statementExecutionFailed, got \(error)")
            }

            XCTAssertEqual(sql, "INVALID SQL")
            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     transaction 내부 작업이 성공하면 commit 되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_transaction_commitsChanges() throws {
        let storage = try InMemorySQLiteStorage.make()

        try storage.execute(
            sql: """
            CREATE TABLE items (
                id TEXT PRIMARY KEY
            );
            """
        )

        try storage.transaction { databasePointer in
            guard sqlite3_exec(
                databasePointer,
                "INSERT INTO items (id) VALUES ('1');",
                nil,
                nil,
                nil
            ) == SQLITE_OK else {
                throw SearchEngineError.statementExecutionFailed(
                    sql: "INSERT INTO items (id) VALUES ('1');",
                    message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                )
            }
        }

        let count = try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM items;",
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
     transaction 내부 작업이 실패하면 rollback 되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_transaction_rollsBackOnFailure() throws {
        let storage = try InMemorySQLiteStorage.make()

        try storage.execute(
            sql: """
            CREATE TABLE items (
                id TEXT PRIMARY KEY
            );
            """
        )

        XCTAssertThrowsError(
            try storage.transaction { databasePointer in
                guard sqlite3_exec(
                    databasePointer,
                    "INSERT INTO items (id) VALUES ('1');",
                    nil,
                    nil,
                    nil
                ) == SQLITE_OK else {
                    throw SearchEngineError.statementExecutionFailed(
                        sql: "INSERT INTO items (id) VALUES ('1');",
                        message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                    )
                }

                throw SearchEngineError.transactionFailed(
                    message: "Forced rollback"
                )
            }
        )

        let count = try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM items;",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }

        XCTAssertEqual(count, 0)
    }
}
