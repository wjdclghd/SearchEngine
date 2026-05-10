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

/// SQLiteStorage의 기본 읽기/쓰기 및 트랜잭션 동작을 검증하는 테스트입니다.
///
/// SearchEngine의 색인, 검색, 자동완성 Store가 공통으로 사용하는
/// SQL 실행과 트랜잭션 롤백 기반을 검증합니다.
final class SQLiteStorageTests: XCTestCase {

    func test_execute_readAndWrite_succeeds() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        try storage.execute(
            sql: """
            CREATE TABLE items (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL
            );
            """
        )

        // when
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

        // then
        XCTAssertEqual(title, "SwiftUI")
    }

    func test_execute_withInvalidSQL_throwsStatementExecutionFailed() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()

        // when / then
        XCTAssertThrowsError(try storage.execute(sql: "INVALID SQL")) { error in
            guard case let SearchEngineError.statementExecutionFailed(sql, message) = error else {
                return XCTFail("Expected statementExecutionFailed, got \(error)")
            }

            XCTAssertEqual(sql, "INVALID SQL")
            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_transaction_commitsChanges() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        try storage.execute(
            sql: """
            CREATE TABLE items (
                id TEXT PRIMARY KEY
            );
            """
        )

        // when
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

        // then
        XCTAssertEqual(count, 1)
    }

    func test_transaction_rollsBackOnFailure() throws {
        // given
        let storage = try InMemorySQLiteStorage.make()
        try storage.execute(
            sql: """
            CREATE TABLE items (
                id TEXT PRIMARY KEY
            );
            """
        )

        // when
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

        // then
        XCTAssertEqual(count, 0)
    }
}
