//
//  SearchEngineMigrationPlan.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3

/*
 SearchEngine 저장소를 열 때 적용할 SQLite migration 정책을 정의하는 설정 타입입니다.

 SearchEngine은 SQLite 기반 로컬 검색 인덱스를 확장하게 되므로,
 스키마 버전과 버전별 SQL 변경 이력을 한 곳에서 관리할 수 있어야 합니다.
 이 타입은 migration version, 적용 순서, 실행 SQL 목록을 값 타입으로 보관하여
 SearchEngineConfiguration과 SQLiteDatabase가 동일한 규칙으로 migration을 수행하도록 돕습니다.

 또한 동일한 migration plan 위에 신규 스키마를 안전하게 추가할 수 있도록
 확장 지점을 미리 마련합니다.
 */
public struct SearchEngineMigrationPlan: Equatable, Sendable {
    /*
     버전별 SQLite migration 한 건을 표현하는 값 타입입니다.

     하나의 migration은 단일 target version과,
     해당 버전에 도달하기 위해 순서대로 실행할 SQL 문 목록을 함께 보관합니다.
     */
    public struct Migration: Equatable, Sendable {
        /*
         migration이 완료된 뒤 기록할 user_version 값입니다.
         */
        public let version: Int32

        /*
         해당 버전으로 올리기 위해 순서대로 실행할 SQL 목록입니다.
         */
        public let statements: [String]

        /*
         migration 한 건을 생성합니다.

         Parameters:
         - version: migration이 완료된 뒤 기록할 user_version 값
         - statements: 해당 버전으로 올리기 위해 순서대로 실행할 SQL 목록
         */
        public init(
            version: Int32,
            statements: [String]
        ) {
            self.version = version
            self.statements = statements
        }
    }

    /*
     SearchEngine이 순서대로 적용할 migration 목록입니다.
     */
    public let migrations: [Migration]

    /*
     migration plan을 생성합니다.

     Parameters:
     - migrations: 순서대로 적용할 migration 목록
     */
    public init(migrations: [Migration]) {
        self.migrations = migrations
    }

    /*
     현재 plan이 도달할 최신 schema version입니다.
     */
    public var latestVersion: Int32 {
        migrations.last?.version ?? 0
    }

    /*
     SearchEngine 기본 migration 정책입니다.

     검색 엔진 내부 메타데이터 테이블을 준비하고,
     버전 2 이상 migration을 순차적으로 이어갈 수 있도록 user_version 1을 기준점으로 사용합니다.
     */
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

    /*
     migration을 수행하지 않는 정책입니다.

     이미 준비된 데이터베이스를 읽기 전용으로 열거나,
     migration 수행을 외부에서 별도로 관리하는 환경에서 사용할 수 있습니다.
     */
    public static let disabled = SearchEngineMigrationPlan(migrations: [])
}

extension SearchEngineMigrationPlan {
    /*
     migration plan 구성이 유효한지 검증합니다.

     migration version은 1부터 시작해 오름차순으로 연속되어야 하며,
     각 migration은 최소 한 개 이상의 유효한 SQL 문을 포함해야 합니다.
     이렇게 해야 특정 버전에서 다음 버전으로 이동하는 경로가 모호해지지 않고,
     migration 이력을 안정적으로 이어갈 수 있습니다.

     Throws:
     - SearchEngineError.invalidConfiguration: migration plan 구성이 잘못된 경우
     */
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

    /*
     지정한 현재 버전 이후에 적용해야 할 migration 목록을 반환합니다.

     Parameters:
     - version: 현재 데이터베이스가 기록 중인 user_version

     Returns:
     - 아직 적용되지 않은 migration 목록
     */
    func pendingMigrations(after version: Int32) -> [Migration] {
        migrations.filter { $0.version > version }
    }

    /*
     현재 데이터베이스 상태에 필요한 migration을 적용합니다.

     내부적으로 PRAGMA user_version을 읽어 현재 버전을 확인한 뒤,
     아직 적용되지 않은 migration만 transaction 안에서 순서대로 실행합니다.
     각 migration이 끝날 때마다 user_version을 갱신하여,
     다음 앱 실행에서도 같은 migration이 중복 적용되지 않도록 보장합니다.

     Parameters:
     - database: migration을 적용할 SQLite foundation

     Throws:
     - SearchEngineError.invalidConfiguration: migration plan 검증 실패
     - SearchEngineError.migrationFailed: 버전 불일치 또는 migration SQL 적용 실패
     */
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
    /*
     migration plan에서 사용할 SQLite statement를 준비합니다.

     Parameters:
     - sql: 준비할 SQL 문자열
     - databasePointer: statement를 준비할 SQLite 연결 포인터

     Returns:
     - 준비된 SQLite statement 포인터

     Throws:
     - statement 준비에 실패하면 migrationFailed 에러를 던집니다.
     */
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

    /*
     migration plan에서 준비한 SQLite statement를 안전하게 정리합니다.

     Parameters:
     - statement: 정리할 SQLite statement 포인터
     */
    static func finalizeStatement(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }

    /*
     migration plan에서 사용할 최근 SQLite 오류 메시지를 반환합니다.

     Parameters:
     - databasePointer: 오류 메시지를 조회할 SQLite 연결 포인터

     Returns:
     - SQLite 오류 메시지 문자열
     */
    static func lastErrorMessage(from databasePointer: OpaquePointer) -> String {
        guard let cString = sqlite3_errmsg(databasePointer) else {
            return "Unknown SQLite error."
        }

        return String(cString: cString)
    }

    /*
     현재 SQLite user_version 값을 조회합니다.

     Parameters:
     - databasePointer: user_version을 읽을 SQLite 연결 포인터

     Returns:
     - 현재 데이터베이스의 user_version 값

     Throws:
     - user_version 조회에 실패하면 에러를 던집니다.
     */
    static func fetchUserVersion(
        in databasePointer: OpaquePointer
    ) throws -> Int32 {
        let statement = try prepareStatement(
            sql: "PRAGMA user_version;",
            in: databasePointer
        )
        defer { finalizeStatement(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SearchEngineError.migrationFailed(
                message: "Unable to read PRAGMA user_version."
            )
        }

        return sqlite3_column_int(statement, 0)
    }

    /*
     SQLite user_version 값을 지정한 버전으로 갱신합니다.

     Parameters:
     - version: 기록할 migration version
     - databasePointer: user_version을 갱신할 SQLite 연결 포인터

     Throws:
     - user_version 갱신에 실패하면 에러를 던집니다.
     */
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

    /*
     migration SQL 한 문장을 실행합니다.

     Parameters:
     - sql: 실행할 migration SQL 문자열
     - version: 현재 적용 중인 migration version
     - databasePointer: SQL을 실행할 SQLite 연결 포인터

     Throws:
     - SQL 실행에 실패하면 에러를 던집니다.
     */
    static func executeMigrationStatement(
        _ sql: String,
        version: Int32,
        in databasePointer: OpaquePointer
    ) throws {
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSQL.isEmpty {
            throw SearchEngineError.migrationFailed(
                message: "Migration version \(version) contains an empty SQL statement."
            )
        }

        guard sqlite3_exec(databasePointer, trimmedSQL, nil, nil, nil) == SQLITE_OK else {
            throw SearchEngineError.migrationFailed(
                message: "Failed to execute migration version \(version). sql: \(trimmedSQL). \(lastErrorMessage(from: databasePointer))"
            )
        }
    }
}
