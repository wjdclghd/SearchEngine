//
//  SearchEngineMigrationPlanTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchEngineMigrationPlan의 버전 관리와 검증 동작을 확인하는 테스트입니다.

 스키마 변경 SQL 자체보다도
 버전 순서와 적용 대상 계산 규칙이 흔들리지 않는 것이 중요합니다.
 이 테스트는 연속 버전 규칙, 빈 SQL 차단, pending migration 계산이 올바른지 검증합니다.
 */
final class SearchEngineMigrationPlanTests: XCTestCase {
    /*
     기본 migration plan이 최신 버전 1을 가리키는지 검증합니다.
     */
    func test_sqliteCore_latestVersion_isOne() {
        XCTAssertEqual(SearchEngineMigrationPlan.sqliteCore.latestVersion, 1)
    }

    /*
     연속된 migration plan은 검증을 통과하는지 검증합니다.
     */
    func test_validate_withContiguousVersions_succeeds() {
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["CREATE TABLE v1_items (id TEXT PRIMARY KEY);"]),
                .init(version: 2, statements: ["CREATE TABLE v2_items (id TEXT PRIMARY KEY);"])
            ]
        )

        XCTAssertNoThrow(try migrationPlan.validate())
    }

    /*
     연속되지 않은 migration version이 있으면 invalidConfiguration을 반환하는지 검증합니다.
     */
    func test_validate_withNonContiguousVersions_throwsInvalidConfiguration() {
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["CREATE TABLE v1_items (id TEXT PRIMARY KEY);"]),
                .init(version: 3, statements: ["CREATE TABLE v3_items (id TEXT PRIMARY KEY);"])
            ]
        )

        XCTAssertThrowsError(try migrationPlan.validate()) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     빈 SQL 문이 포함된 migration plan은 invalidConfiguration을 반환하는지 검증합니다.
     */
    func test_validate_withEmptySQLStatement_throwsInvalidConfiguration() {
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["   "])
            ]
        )

        XCTAssertThrowsError(try migrationPlan.validate()) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     현재 버전 이후에 필요한 migration만 반환하는지 검증합니다.
     */
    func test_pendingMigrations_afterVersion_returnsRemainingMigrations() {
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["CREATE TABLE v1_items (id TEXT PRIMARY KEY);"]),
                .init(version: 2, statements: ["CREATE TABLE v2_items (id TEXT PRIMARY KEY);"]),
                .init(version: 3, statements: ["CREATE TABLE v3_items (id TEXT PRIMARY KEY);"])
            ]
        )

        let pendingMigrations = migrationPlan.pendingMigrations(after: 1)

        XCTAssertEqual(pendingMigrations.map(\.version), [2, 3])
    }

    /*
     현재 데이터베이스 버전이 migration plan 최신 버전보다 높으면 migrationFailed를 반환하는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_apply_whenCurrentVersionIsNewerThanPlan_throwsMigrationFailed() throws {
        let temporaryBaseDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let expandedMigrationPlan = SearchEngineMigrationPlan(
            migrations: SearchEngineMigrationPlan.sqliteCore.migrations + [
                .init(
                    version: 2,
                    statements: [
                        "CREATE TABLE IF NOT EXISTS migration_v2_items (id TEXT PRIMARY KEY);"
                    ]
                )
            ]
        )

        addTeardownBlock {
            try? FileManager.default.removeItem(at: temporaryBaseDirectoryURL)
        }

        let initialConfiguration = try SearchEngineConfiguration.live(
            directoryName: "SearchEngine",
            fileName: "SearchEngine.sqlite",
            baseDirectoryURL: temporaryBaseDirectoryURL,
            migrationPlan: expandedMigrationPlan,
            enablesWriteAheadLogging: false,
            enablesForeignKeys: true
        )
        let database = try SQLiteDatabase(configuration: initialConfiguration)

        XCTAssertThrowsError(
            try SearchEngineMigrationPlan.sqliteCore.apply(using: database)
        ) { error in
            guard case let SearchEngineError.migrationFailed(message) = error else {
                return XCTFail("Expected migrationFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

}
