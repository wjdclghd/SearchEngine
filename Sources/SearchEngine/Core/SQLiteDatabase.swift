//
//  SQLiteDatabase.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation
import SQLite3

/// SQLite3 연결을 직접 관리하는 SearchEngine의 기반 구현체입니다.
final class SQLiteDatabase: SQLiteDatabaseProtocol {
    /// 데이터베이스 구성 값입니다.
    let configuration: SearchEngineConfiguration

    /// SQLite 데이터베이스 연결 포인터입니다.
    private let databasePointer: OpaquePointer

    /// SQLite 접근 직렬화를 위한 lock입니다.
    ///
    /// 하나의 연결을 기준으로 읽기, 쓰기, 트랜잭션 경로를 일관되게 보호하기 위해 사용합니다.
    private let lock = NSRecursiveLock()

    init(configuration: SearchEngineConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration

        let openedDatabasePointer = try SQLiteDatabase.openDatabase(configuration: configuration)

        do {
            try SQLiteDatabase.configureDatabase(
                databasePointer: openedDatabasePointer,
                configuration: configuration
            )
            self.databasePointer = openedDatabasePointer
            try configuration.migrationPlan.apply(using: self)
        } catch {
            sqlite3_close_v2(openedDatabasePointer)
            throw error
        }
    }

    deinit {
        sqlite3_close_v2(databasePointer)
    }

    /// SQL 한 문장을 직접 실행합니다.
    ///
    /// - Parameter sql: 실행할 SQL 문자열입니다.
    ///
    /// - Throws: SQL 실행에 실패하면 에러를 던집니다.
    func execute(sql: String) throws {
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSQL.isEmpty {
            throw SearchEngineError.statementExecutionFailed(
                sql: sql,
                message: "SQL must not be empty."
            )
        }

        try write { databasePointer in
            guard sqlite3_exec(databasePointer, trimmedSQL, nil, nil, nil) == SQLITE_OK else {
                throw SearchEngineError.statementExecutionFailed(
                    sql: trimmedSQL,
                    message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                )
            }
        }
    }

    /// 읽기 작업을 수행합니다.
    ///
    /// - Parameter operation: SQLite 연결 포인터를 받아 읽기 작업을 수행하는 클로저입니다.
    ///
    /// - Returns: 읽기 작업 결과 값입니다.
    ///
    /// - Throws: 읽기 작업에 실패하면 에러를 던집니다.
    func read<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try performLockedOperation(
            defaultErrorTransform: { SearchEngineError.readFailed(message: $0.localizedDescription) },
            operation: operation
        )
    }

    /// 쓰기 작업을 수행합니다.
    ///
    /// - Parameter operation: SQLite 연결 포인터를 받아 쓰기 작업을 수행하는 클로저입니다.
    ///
    /// - Returns: 쓰기 작업 결과 값입니다.
    ///
    /// - Throws: 쓰기 작업에 실패하면 에러를 던집니다.
    func write<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try performLockedOperation(
            defaultErrorTransform: { SearchEngineError.writeFailed(message: $0.localizedDescription) },
            operation: operation
        )
    }

    /// 트랜잭션 안에서 작업을 수행합니다.
    ///
    /// - Parameter operation: SQLite 연결 포인터를 받아 트랜잭션 작업을 수행하는 클로저입니다.
    ///
    /// - Returns: 트랜잭션 작업 결과 값입니다.
    ///
    /// - Throws: 트랜잭션 실행에 실패하면 에러를 던집니다.
    func transaction<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try write { databasePointer in
            guard sqlite3_exec(databasePointer, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil) == SQLITE_OK else {
                throw SearchEngineError.transactionFailed(
                    message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                )
            }

            do {
                let result = try operation(databasePointer)

                guard sqlite3_exec(databasePointer, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
                    throw SearchEngineError.transactionFailed(
                        message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                    )
                }

                return result
            } catch {
                let rollbackResult = sqlite3_exec(databasePointer, "ROLLBACK;", nil, nil, nil)

                if rollbackResult != SQLITE_OK {
                    throw SearchEngineError.transactionFailed(
                        message: "Transaction failed and rollback also failed. \(SQLiteDatabase.lastErrorMessage(from: databasePointer))"
                    )
                }

                if let searchEngineError = error as? SearchEngineError {
                    throw searchEngineError
                }

                throw SearchEngineError.transactionFailed(message: error.localizedDescription)
            }
        }
    }
}

extension SQLiteDatabase {
    /// SQLite statement를 준비합니다.
    ///
    /// - Parameter sql: 준비할 SQL 문자열입니다.
    /// - Parameter databasePointer: statement를 준비할 SQLite 연결 포인터입니다.
    ///
    /// - Returns: 준비된 SQLite statement 포인터입니다.
    ///
    /// - Throws: statement 준비에 실패하면 에러를 던집니다.
    static func prepareStatement(
        sql: String,
        in databasePointer: OpaquePointer
    ) throws -> OpaquePointer {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(databasePointer, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SearchEngineError.statementPreparationFailed(
                sql: sql,
                message: lastErrorMessage(from: databasePointer)
            )
        }

        return statement
    }

    /// SQLite statement를 안전하게 정리합니다.
    ///
    /// - Parameter statement: 정리할 SQLite statement 포인터입니다.
    static func finalizeStatement(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }

    /// 최근 SQLite 오류 메시지를 반환합니다.
    ///
    /// - Parameter databasePointer: 오류 메시지를 조회할 SQLite 연결 포인터입니다.
    ///
    /// - Returns: SQLite 오류 메시지 문자열입니다.
    static func lastErrorMessage(from databasePointer: OpaquePointer) -> String {
        guard let cString = sqlite3_errmsg(databasePointer) else {
            return "Unknown SQLite error."
        }

        return String(cString: cString)
    }

    /// 문자열 값을 SQLite parameter에 바인딩합니다.
    ///
    /// - Parameter value: 바인딩할 문자열 값입니다.
    /// - Parameter statement: 값을 바인딩할 SQLite statement입니다.
    /// - Parameter index: parameter 인덱스입니다.
    ///
    /// - Throws: 바인딩에 실패하면 statementBindingFailed를 던집니다.
    static func bind(_ value: String, to statement: OpaquePointer, index: Int32) throws {
        let result = value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransientDestructor)
        }

        guard result == SQLITE_OK else {
            throw SearchEngineError.statementBindingFailed(
                index: index,
                message: "Failed to bind text parameter."
            )
        }
    }

    /// 실수 값을 SQLite parameter에 바인딩합니다.
    ///
    /// - Parameter value: 바인딩할 실수 값입니다.
    /// - Parameter statement: 값을 바인딩할 SQLite statement입니다.
    /// - Parameter index: parameter 인덱스입니다.
    ///
    /// - Throws: 바인딩에 실패하면 statementBindingFailed를 던집니다.
    static func bind(_ value: Double, to statement: OpaquePointer, index: Int32) throws {
        let result = sqlite3_bind_double(statement, index, value)

        guard result == SQLITE_OK else {
            throw SearchEngineError.statementBindingFailed(
                index: index,
                message: "Failed to bind double parameter."
            )
        }
    }

    /// 정수 값을 SQLite parameter에 바인딩합니다.
    ///
    /// - Parameter value: 바인딩할 정수 값입니다.
    /// - Parameter statement: 값을 바인딩할 SQLite statement입니다.
    /// - Parameter index: parameter 인덱스입니다.
    ///
    /// - Throws: 바인딩에 실패하면 statementBindingFailed를 던집니다.
    static func bind(_ value: Int, to statement: OpaquePointer, index: Int32) throws {
        let result = sqlite3_bind_int64(statement, index, sqlite3_int64(value))

        guard result == SQLITE_OK else {
            throw SearchEngineError.statementBindingFailed(
                index: index,
                message: "Failed to bind integer parameter."
            )
        }
    }

    /// SQLite 문자열 바인딩에서 사용할 transient destructor입니다.
    static var sqliteTransientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    /// 필수 문자열 컬럼을 읽습니다.
    ///
    /// - Parameter statement: 값을 읽을 SQLite statement입니다.
    /// - Parameter column: 읽을 컬럼 인덱스입니다.
    /// - Parameter columnName: 오류 메시지에 사용할 컬럼 이름입니다.
    /// - Parameter sql: 오류 메시지에 사용할 SQL 문자열입니다.
    ///
    /// - Returns: 읽은 문자열 값입니다.
    ///
    /// - Throws: 문자열 컬럼을 읽지 못하면 statementExecutionFailed를 던집니다.
    static func readRequiredText(
        from statement: OpaquePointer,
        column: Int32,
        columnName: String,
        sql: String
    ) throws -> String {
        guard let cString = sqlite3_column_text(statement, column) else {
            throw SearchEngineError.statementExecutionFailed(
                sql: sql,
                message: "Missing required text column: \(columnName)."
            )
        }

        return String(cString: cString)
    }

    /// 선택 문자열 컬럼을 읽습니다.
    ///
    /// - Parameter statement: 값을 읽을 SQLite statement입니다.
    /// - Parameter column: 읽을 컬럼 인덱스입니다.
    ///
    /// - Returns: 읽은 문자열 값 또는 nil입니다.
    static func readOptionalText(from statement: OpaquePointer, column: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else {
            return nil
        }

        return String(cString: cString)
    }
}

private extension SQLiteDatabase {
    /// 구성 값에 따라 SQLite 데이터베이스 연결을 엽니다.
    ///
    /// - Parameter configuration: 데이터베이스 초기화에 사용할 구성 값입니다.
    ///
    /// - Returns: 열린 SQLite 연결 포인터입니다.
    ///
    /// - Throws: 데이터베이스 열기에 실패하면 에러를 던집니다.
    static func openDatabase(
        configuration: SearchEngineConfiguration
    ) throws -> OpaquePointer {
        let openFlags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
        var databasePointer: OpaquePointer?
        let connectionPath: String

        switch configuration.storage {
        case .sqlite:
            guard let databaseURL = try configuration.databaseURL() else {
                throw SearchEngineError.databasePathUnavailable(
                    message: "Unable to resolve SQLite database URL."
                )
            }

            connectionPath = databaseURL.path

        case .inMemory:
            connectionPath = try configuration.inMemoryConnectionString()
        }

        guard sqlite3_open_v2(connectionPath, &databasePointer, openFlags, nil) == SQLITE_OK,
              let databasePointer else {
            throw SearchEngineError.databaseOpenFailed(
                message: databasePointer.map(SQLiteDatabase.lastErrorMessage(from:))
                ?? "Unable to open SQLite database connection."
            )
        }

        return databasePointer
    }

    /// 데이터베이스 공통 pragma를 적용합니다.
    ///
    /// - Parameter databasePointer: pragma를 적용할 SQLite 연결 포인터입니다.
    /// - Parameter configuration: 적용할 설정값입니다.
    ///
    /// - Throws: pragma 적용에 실패하면 에러를 던집니다.
    static func configureDatabase(
        databasePointer: OpaquePointer,
        configuration: SearchEngineConfiguration
    ) throws {
        guard sqlite3_busy_timeout(databasePointer, configuration.busyTimeoutMilliseconds) == SQLITE_OK else {
            throw SearchEngineError.databaseOpenFailed(
                message: lastErrorMessage(from: databasePointer)
            )
        }

        if configuration.enablesWriteAheadLogging {
            try executePragma(
                "PRAGMA journal_mode = WAL;",
                databasePointer: databasePointer
            )
        }

        let foreignKeyValue = configuration.enablesForeignKeys ? "ON" : "OFF"
        try executePragma(
            "PRAGMA foreign_keys = \(foreignKeyValue);",
            databasePointer: databasePointer
        )
    }

    /// 공통 lock 아래에서 SQLite 작업을 수행합니다.
    ///
    /// - Parameter defaultErrorTransform: SearchEngineError가 아닌 일반 오류를 기본 모듈 에러로 변환하는 클로저입니다.
    /// - Parameter operation: SQLite 연결 포인터를 받아 실행할 작업 클로저입니다.
    ///
    /// - Returns: 작업 결과 값입니다.
    ///
    /// - Throws: 작업 실패 시 변환된 SearchEngineError를 던집니다.
    func performLockedOperation<T>(
        defaultErrorTransform: (Error) -> SearchEngineError,
        operation: (OpaquePointer) throws -> T
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        do {
            return try operation(databasePointer)
        } catch let error as SearchEngineError {
            throw error
        } catch {
            throw defaultErrorTransform(error)
        }
    }

    /// pragma SQL 한 문장을 실행합니다.
    ///
    /// - Parameter sql: 실행할 pragma SQL 문자열입니다.
    /// - Parameter databasePointer: pragma를 적용할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: pragma 실행에 실패하면 에러를 던집니다.
    static func executePragma(
        _ sql: String,
        databasePointer: OpaquePointer
    ) throws {
        guard sqlite3_exec(databasePointer, sql, nil, nil, nil) == SQLITE_OK else {
            throw SearchEngineError.statementExecutionFailed(
                sql: sql,
                message: lastErrorMessage(from: databasePointer)
            )
        }
    }
}
