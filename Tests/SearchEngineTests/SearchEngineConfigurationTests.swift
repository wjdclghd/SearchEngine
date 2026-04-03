//
//  SearchEngineConfigurationTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchEngineConfiguration의 기본 설정값과 검증 동작을 확인하는 테스트입니다.

 이 테스트는 환경별 팩토리 메서드가 올바른 저장소 종류를 선택하는지,
 디스크 기반 SQLite 저장소 URL이 예상한 위치에 생성되는지,
 잘못된 directoryName, fileName, identifier, timeout 값이
 foundation 전체 초기화로 넘어가기 전에 정확히 차단되는지를 검증합니다.
 */
final class SearchEngineConfigurationTests: XCTestCase {
    /*
     in-memory 설정에서 databaseURL이 nil을 반환하는지 검증합니다.

     메모리 저장소는 디스크 파일 경로를 사용하지 않으므로,
     URL 계산 결과가 nil이어야 이후 초기화 흐름이 일관됩니다.
     */
    func test_inMemoryConfiguration_databaseURL_returnsNil() throws {
        let configuration = SearchEngineConfiguration.inMemory()
        XCTAssertNil(try configuration.databaseURL())
    }

    /*
     inMemory 설정이 in-memory 저장소를 사용하도록 구성되는지 검증합니다.

     테스트 환경에서는 디스크 저장소 대신 in-memory 저장소를 사용해야 하므로,
     storage가 정확히 .inMemory로 설정되는지를 확인합니다.
     */
    func test_inMemoryConfiguration_usesInMemoryStorage() {
        let configuration = SearchEngineConfiguration.inMemory()

        guard case .inMemory = configuration.storage else {
            return XCTFail("Expected in-memory storage")
        }
    }

    /*
     live 설정이 지정한 기준 디렉터리 아래에 SQLite 파일 URL을 생성하는지 검증합니다.

     테스트에서는 Application Support를 직접 사용하지 않고,
     임시 디렉터리를 기준 경로로 주입하여 파일 시스템 부작용을 줄입니다.
     생성된 URL이 sqlite 확장자를 가지며 디렉터리 경로 규칙이 유지되는지를 확인합니다.
     */
    func test_liveConfiguration_createsSQLiteURL() throws {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }

        let configuration = try SearchEngineConfiguration.live(
            directoryName: "SearchEngine",
            fileName: "SearchEngine.sqlite",
            baseDirectoryURL: temporaryDirectoryURL
        )

        let databaseURL = try configuration.databaseURL()

        XCTAssertEqual(databaseURL?.pathExtension, "sqlite")
        XCTAssertEqual(databaseURL?.deletingLastPathComponent().lastPathComponent, "SearchEngine")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: databaseURL?.deletingLastPathComponent().path ?? ""
            )
        )
    }


    /*
     baseDirectoryURL 없이 live 설정을 생성해도 기본 Application Support 경로를 기준으로
     SQLite 파일 URL이 계산되는지 검증합니다.

     테스트에서는 고유한 directoryName과 fileName을 사용하여
     기본 경로 해석 로직만 확인하고, 테스트 종료 후 생성된 디렉터리를 정리합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_liveConfiguration_withoutBaseDirectoryURL_resolvesApplicationSupportPath() throws {
        let directoryName = "SearchEngineTests.\(UUID().uuidString)"
        let fileName = "SearchEngineTests.sqlite"
        let applicationSupportURL = try XCTUnwrap(
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        )
        let expectedDirectoryURL = applicationSupportURL
            .appendingPathComponent(directoryName, isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: expectedDirectoryURL)
        }

        let configuration = try SearchEngineConfiguration.live(
            directoryName: directoryName,
            fileName: fileName,
            baseDirectoryURL: nil
        )

        let databaseURL = try XCTUnwrap(configuration.databaseURL())

        XCTAssertEqual(databaseURL.deletingLastPathComponent(), expectedDirectoryURL)
        XCTAssertEqual(databaseURL.lastPathComponent, fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDirectoryURL.path))
    }

    /*
     live 설정에서 fileName이 비어 있으면 invalidConfiguration이 발생하는지 검증합니다.

     저장소 경로를 만들기 전에 잘못된 설정을 차단하면,
     파일 시스템 작업 중 발생하는 모호한 오류 대신 명확한 원인을 전달할 수 있습니다.
     */
    func test_liveConfiguration_withEmptyFileName_throwsInvalidConfiguration() {
        XCTAssertThrowsError(
            try SearchEngineConfiguration.live(fileName: " ")
        ) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     inMemory 설정에서 identifier가 비어 있으면 validate가 invalidConfiguration을 반환하는지 검증합니다.

     메모리 저장소도 shared cache URI를 만들기 위해 식별자가 필요하므로,
     빈 문자열은 foundation 단계에서 미리 차단되어야 합니다.
     */
    func test_validate_withEmptyInMemoryIdentifier_throwsInvalidConfiguration() {
        let configuration = SearchEngineConfiguration.inMemory(identifier: "   ")

        XCTAssertThrowsError(try configuration.validate()) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     busy timeout 값이 음수이면 invalidConfiguration이 발생하는지 검증합니다.

     SQLite foundation이 잘못된 timeout 값으로 초기화되면,
     실제 동작 시점에 불명확한 실패를 만들 수 있으므로 설정 객체에서 먼저 차단합니다.
     */
    func test_validate_withNegativeBusyTimeout_throwsInvalidConfiguration() {
        let configuration = SearchEngineConfiguration(
            storage: .inMemory(identifier: "SearchEngine.Tests"),
            busyTimeoutMilliseconds: -1,
            enablesWriteAheadLogging: false,
            enablesForeignKeys: true
        )

        XCTAssertThrowsError(try configuration.validate()) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }


    /*
     live 설정에서 directoryName이 비어 있으면 invalidConfiguration이 발생하는지 검증합니다.

     저장소 디렉터리 이름이 비어 있으면 경로 계산 규칙이 무너지므로,
     파일 시스템 작업 전에 명확한 설정 오류로 차단되어야 합니다.
     */
    func test_liveConfiguration_withEmptyDirectoryName_throwsInvalidConfiguration() {
        XCTAssertThrowsError(
            try SearchEngineConfiguration.live(directoryName: " ")
        ) { error in
            guard case let SearchEngineError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
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
        let configuration = SearchEngineConfiguration.inMemory(identifier: "Search Engine Tests")
        let connectionString = try configuration.inMemoryConnectionString()

        XCTAssertTrue(connectionString.hasPrefix("file:"))
        XCTAssertTrue(connectionString.contains("mode=memory"))
        XCTAssertTrue(connectionString.contains("cache=shared"))
    }

    /*
     busy timeout 값이 0이면 유효한 설정으로 허용되는지 검증합니다.
     */
    func test_validate_withZeroBusyTimeout_succeeds() {
        let configuration = SearchEngineConfiguration(
            storage: .inMemory(identifier: "SearchEngine.Tests"),
            busyTimeoutMilliseconds: 0,
            enablesWriteAheadLogging: false,
            enablesForeignKeys: true
        )

        XCTAssertNoThrow(try configuration.validate())
    }

}
