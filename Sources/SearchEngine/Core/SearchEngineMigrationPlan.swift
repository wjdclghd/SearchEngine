//
//  SearchEngineMigrationPlan.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3

/// SearchEngine 저장소를 열 때 적용할 SQLite migration 정책을 정의하는 설정 타입입니다.
public struct SearchEngineMigrationPlan: Equatable, Sendable {
    /// 버전별 SQLite migration 한 건을 표현하는 값 타입입니다.
    ///
    /// 하나의 migration은 단일 target version과,
    /// 해당 버전에 도달하기 위해 순서대로 실행할 SQL 문 목록을 함께 보관합니다.
    public struct Migration: Equatable, Sendable {
        /// migration이 완료된 뒤 기록할 user_version 값입니다.
        public let version: Int32

        /// 해당 버전으로 올리기 위해 순서대로 실행할 SQL 목록입니다.
        public let statements: [String]

        /// migration 한 건을 생성합니다.
        ///
        /// - Parameter version: migration이 완료된 뒤 기록할 user_version 값입니다.
        /// - Parameter statements: 해당 버전으로 올리기 위해 순서대로 실행할 SQL 목록입니다.
        public init(
            version: Int32,
            statements: [String]
        ) {
            self.version = version
            self.statements = statements
        }
    }

    /// SearchEngine이 순서대로 적용할 migration 목록입니다.
    public let migrations: [Migration]

    /// migration plan을 생성합니다.
    ///
    /// - Parameter migrations: 순서대로 적용할 migration 목록입니다.
    public init(migrations: [Migration]) {
        self.migrations = migrations
    }

    /// 현재 plan이 도달할 최신 schema version입니다.
    public var latestVersion: Int32 {
        migrations.last?.version ?? 0
    }

    /// SearchEngine 초기 메타데이터 준비용 migration 정책입니다.
    public static let sqliteCore = SearchEngineMigrationPlan(
        migrations: [
            Migration(
                version: 1,
                statements: [
                    SearchEngineMigrationSQL.createMetadataTable,
                    SearchEngineMigrationSQL.createMetadataUpdatedAtIndex
                ]
            )
        ]
    )

    /// SearchEngine 문서 색인 스키마까지 포함한 기본 migration 정책입니다.
    public static let searchIndexing = SearchEngineMigrationPlan(
        migrations: sqliteCore.migrations + [
            Migration(
                version: 2,
                statements: [
                    SearchEngineMigrationSQL.createDocumentsTable,
                    SearchEngineMigrationSQL.createDocumentsScopeUpdatedAtIndex,
                    SearchEngineMigrationSQL.createDocumentsFTSTable
                ]
            )
        ]
    )

    /// migration을 수행하지 않는 정책입니다.
    ///
    /// 이미 준비된 데이터베이스를 읽기 전용으로 열거나,
    /// migration 수행을 외부에서 별도로 관리하는 환경에서 사용할 수 있습니다.
    public static let disabled = SearchEngineMigrationPlan(migrations: [])
}

extension SearchEngineMigrationPlan {
    /// migration plan 구성이 유효한지 검증합니다.
    ///
    /// - Throws: migration plan 구성이 잘못된 경우 SearchEngineError.invalidConfiguration을 던집니다.
    func validate() throws {
        guard migrations.isEmpty == false else {
            return
        }

        var expectedVersion: Int32 = 1

        for migration in migrations {
            if migration.version != expectedVersion {
                throw SearchEngineError.invalidConfiguration(
                    message: "Migration versions must start at 1 and increase by 1. expected: \(expectedVersion), actual: \(migration.version)."
                )
            }

            if migration.statements.isEmpty {
                throw SearchEngineError.invalidConfiguration(
                    message: "Migration version \(migration.version) must contain at least one SQL statement."
                )
            }

            let containsEmptyStatement = migration.statements.contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if containsEmptyStatement {
                throw SearchEngineError.invalidConfiguration(
                    message: "Migration version \(migration.version) contains an empty SQL statement."
                )
            }

            expectedVersion += 1
        }
    }

    /// 지정한 현재 버전 이후에 적용해야 할 migration 목록을 반환합니다.
    ///
    /// - Parameter version: 현재 데이터베이스가 기록 중인 user_version입니다.
    ///
    /// - Returns: 아직 적용되지 않은 migration 목록입니다.
    func pendingMigrations(after version: Int32) -> [Migration] {
        migrations.filter { $0.version > version }
    }

    /// 현재 데이터베이스 상태에 필요한 migration을 적용합니다.
    ///
    /// - Parameter database: migration을 적용할 SQLite 기반입니다.
    ///
    /// - Throws: migration plan 검증, 버전 불일치, SQL 적용 실패 시 에러를 던집니다.
    func apply(using database: SQLiteDatabaseProtocol) throws {
        try validate()

        let currentVersion = try database.read { databasePointer in
            try Self.fetchUserVersion(in: databasePointer)
        }

        if latestVersion > 0,
           currentVersion > latestVersion {
            throw SearchEngineError.migrationFailed(
                message: "Current database version \(currentVersion) is newer than migration plan latest version \(latestVersion)."
            )
        }

        let pendingMigrations = pendingMigrations(after: currentVersion)
        guard pendingMigrations.isEmpty == false else {
            return
        }

        try database.transaction { databasePointer in
            for migration in pendingMigrations {
                for statement in migration.statements {
                    try Self.executeMigrationStatement(
                        statement,
                        version: migration.version,
                        in: databasePointer
                    )
                }

                try Self.setUserVersion(migration.version, in: databasePointer)
            }
        }
    }
}

private extension SearchEngineMigrationPlan {
    /// migration plan에서 사용할 SQLite statement를 준비합니다.
    ///
    /// - Parameter sql: 준비할 SQL 문자열입니다.
    /// - Parameter databasePointer: statement를 준비할 SQLite 연결 포인터입니다.
    ///
    /// - Returns: 준비된 SQLite statement 포인터입니다.
    ///
    /// - Throws: statement 준비에 실패하면 migrationFailed 에러를 던집니다.
    static func prepareStatement(
        sql: String,
        in databasePointer: OpaquePointer
    ) throws -> OpaquePointer {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(databasePointer, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SearchEngineError.migrationFailed(
                message: "Failed to prepare migration statement. sql: \(sql). \(lastErrorMessage(from: databasePointer))"
            )
        }

        return statement
    }

    /// migration plan에서 준비한 SQLite statement를 안전하게 정리합니다.
    ///
    /// - Parameter statement: 정리할 SQLite statement 포인터입니다.
    static func finalizeStatement(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }

    /// migration plan에서 사용할 최근 SQLite 오류 메시지를 반환합니다.
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

    /// 현재 SQLite user_version 값을 조회합니다.
    ///
    /// - Parameter databasePointer: user_version을 조회할 SQLite 연결 포인터입니다.
    ///
    /// - Returns: 현재 user_version 값입니다.
    ///
    /// - Throws: user_version 조회에 실패하면 migrationFailed 에러를 던집니다.
    static func fetchUserVersion(in databasePointer: OpaquePointer) throws -> Int32 {
        let statement = try prepareStatement(
            sql: "PRAGMA user_version;",
            in: databasePointer
        )
        defer { finalizeStatement(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SearchEngineError.migrationFailed(
                message: "Failed to read PRAGMA user_version. \(lastErrorMessage(from: databasePointer))"
            )
        }

        return sqlite3_column_int(statement, 0)
    }

    /// 지정한 버전으로 SQLite user_version 값을 갱신합니다.
    ///
    /// - Parameter version: 기록할 target user_version입니다.
    /// - Parameter databasePointer: user_version을 갱신할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: user_version 갱신에 실패하면 migrationFailed 에러를 던집니다.
    static func setUserVersion(
        _ version: Int32,
        in databasePointer: OpaquePointer
    ) throws {
        let pragmaSQL = "PRAGMA user_version = \(version);"

        guard sqlite3_exec(databasePointer, pragmaSQL, nil, nil, nil) == SQLITE_OK else {
            throw SearchEngineError.migrationFailed(
                message: "Failed to update PRAGMA user_version to \(version). \(lastErrorMessage(from: databasePointer))"
            )
        }
    }

    /// migration SQL 한 문장을 실행합니다.
    ///
    /// - Parameter sql: 실행할 migration SQL 문자열입니다.
    /// - Parameter version: 현재 적용 중인 migration version입니다.
    /// - Parameter databasePointer: SQL을 실행할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: migration SQL 실행에 실패하면 migrationFailed 에러를 던집니다.
    static func executeMigrationStatement(
        _ sql: String,
        version: Int32,
        in databasePointer: OpaquePointer
    ) throws {
        guard sqlite3_exec(databasePointer, sql, nil, nil, nil) == SQLITE_OK else {
            throw SearchEngineError.migrationFailed(
                message: "Failed to execute migration version \(version). sql: \(sql). \(lastErrorMessage(from: databasePointer))"
            )
        }
    }
}
