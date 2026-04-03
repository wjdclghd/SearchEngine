//
//  SearchEngineContainerTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3
import XCTest
@testable import SearchEngine

/*
 SearchEngineContainer의 기본 조립 동작을 확인하는 테스트입니다.

 sqlite-core 단계에서는 아직 공개 검색 엔진 구현체를 만들지 않지만,
 컨테이너가 설정값을 보관하고 내부 SQLite foundation을 안정적으로 준비할 수 있어야
 이후 indexing, search, suggest 계층 확장 시 같은 초기화 흐름을 재사용할 수 있습니다.
 */
final class SearchEngineContainerTests: XCTestCase {
    /*
     in-memory 기본 컨테이너가 생성되는지 검증합니다.

     컨테이너는 sqlite-core 단계의 기본 조립 진입점이므로,
     디스크 의존 없는 초기화 경로가 정상 동작하는지 먼저 확인합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_makeDefaultInMemory_createsContainer() throws {
        let container = try SearchEngineContainer.makeDefaultInMemory()

        guard case .inMemory = container.configuration.storage else {
            return XCTFail("Expected in-memory storage")
        }
    }

    /*
     컨테이너가 내부 SQLite 저장 foundation을 구성할 수 있는지 검증합니다.

     이후 기능 브랜치에서는 이 foundation 위에 색인기와 검색 실행기를 조립하게 되므로,
     컨테이너 수준에서 공통 기반이 준비되는지 확인합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_makeSQLiteStorage_returnsUsableStorage() throws {
        let container = try SearchEngineContainer.makeDefaultInMemory()
        let storage = container.makeSQLiteStorage()

        try storage.execute(
            sql: "CREATE TABLE metadata (id TEXT PRIMARY KEY);"
        )

        let count = try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE name = 'metadata';",
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
     makeDefault가 기본 live 경로 규칙을 사용하는 컨테이너를 생성하는지 검증합니다.

     기본 컨테이너는 SearchEngineConfiguration의 기본 디렉터리/파일 이름을 사용해
     Application Support 아래 live SQLite 경로를 계산해야 합니다.
     테스트에서는 파일 존재 여부를 확인하고, 테스트로 새로 생성한 경우에만 정리합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_makeDefault_usesDefaultLivePath() throws {
        let applicationSupportURL = try XCTUnwrap(
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        )
        let expectedDirectoryURL = applicationSupportURL
            .appendingPathComponent(SearchEngineConfiguration.defaultDirectoryName, isDirectory: true)
        let expectedDatabaseURL = expectedDirectoryURL
            .appendingPathComponent(SearchEngineConfiguration.defaultFileName, isDirectory: false)
        let fileExistedBeforeTest = FileManager.default.fileExists(atPath: expectedDatabaseURL.path)

        defer {
            if fileExistedBeforeTest == false {
                try? FileManager.default.removeItem(at: expectedDatabaseURL)
                try? FileManager.default.removeItem(at: expectedDirectoryURL)
            }
        }

        let container = try SearchEngineContainer.makeDefault()
        let storage = container.makeSQLiteStorage()
        let tableName = "metadata_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"

        try storage.execute(
            sql: "CREATE TABLE \(tableName) (id TEXT PRIMARY KEY);"
        )

        guard case let .sqlite(directoryName, fileName, baseDirectoryURL) = container.configuration.storage else {
            return XCTFail("Expected sqlite storage")
        }

        XCTAssertEqual(directoryName, SearchEngineConfiguration.defaultDirectoryName)
        XCTAssertEqual(fileName, SearchEngineConfiguration.defaultFileName)
        XCTAssertNil(baseDirectoryURL)
        XCTAssertEqual(try container.configuration.databaseURL(), expectedDatabaseURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDirectoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDatabaseURL.path))
    }

    /*
     잘못된 설정으로 컨테이너를 생성하면 invalidConfiguration이 발생하는지 검증합니다.
     */
    func test_make_withInvalidConfiguration_throwsInvalidConfiguration() {
        let configuration = SearchEngineConfiguration.inMemory(identifier: "   ")

        XCTAssertThrowsError(try SearchEngineContainer.make(configuration: configuration)) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

}
