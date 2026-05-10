//
//  SearchEngineMigrationPlanTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SearchEngineMigrationPlan의 버전 관리와 검증 동작을 확인하는 테스트입니다.
final class SearchEngineMigrationPlanTests: XCTestCase {
    func test_sqliteCore_latestVersion_isOne() {
        // given / when / then
        XCTAssertEqual(SearchEngineMigrationPlan.sqliteCore.latestVersion, 1)
    }

    func test_validate_withContiguousVersions_succeeds() {
        // given
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["CREATE TABLE v1_items (id TEXT PRIMARY KEY);"]),
                .init(version: 2, statements: ["CREATE TABLE v2_items (id TEXT PRIMARY KEY);"])
            ]
        )

        // when / then
        XCTAssertNoThrow(try migrationPlan.validate())
    }

    func test_validate_withNonContiguousVersions_throwsInvalidConfiguration() {
        // given
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["CREATE TABLE v1_items (id TEXT PRIMARY KEY);"]),
                .init(version: 3, statements: ["CREATE TABLE v3_items (id TEXT PRIMARY KEY);"])
            ]
        )

        // when / then
        XCTAssertThrowsError(try migrationPlan.validate()) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withEmptySQLStatement_throwsInvalidConfiguration() {
        // given
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["   "])
            ]
        )

        // when / then
        XCTAssertThrowsError(try migrationPlan.validate()) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_pendingMigrations_afterVersion_returnsRemainingMigrations() {
        // given
        let migrationPlan = SearchEngineMigrationPlan(
            migrations: [
                .init(version: 1, statements: ["CREATE TABLE v1_items (id TEXT PRIMARY KEY);"]),
                .init(version: 2, statements: ["CREATE TABLE v2_items (id TEXT PRIMARY KEY);"]),
                .init(version: 3, statements: ["CREATE TABLE v3_items (id TEXT PRIMARY KEY);"])
            ]
        )

        // when
        let pendingMigrations = migrationPlan.pendingMigrations(after: 1)

        // then
        XCTAssertEqual(pendingMigrations.map(\.version), [2, 3])
    }

    func test_apply_whenCurrentVersionIsNewerThanPlan_throwsMigrationFailed() throws {
        // given
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

        // when / then
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
