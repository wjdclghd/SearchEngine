//
//  SearchEngineConfiguration.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 SearchEngine 초기화에 필요한 설정 값을 한 곳에 모은 구성 객체입니다.

 SQLite 저장 경로, migration plan, busy timeout, WAL 사용 여부, foreign key 사용 여부를
 함께 관리하여 데이터베이스 초기화 흐름을 일관되게 유지합니다.

 역할
 - live / in-memory 환경별 기본 설정 제공
 - SQLite 파일 경로 계산
 - migration plan 보관 및 검증
 - 필요한 설정값 검증

 담당하지 않는 역할
 - 실제 데이터베이스 연결 열기
 - SQL 실행
 - 검색 / 제안 / 재색인 로직 구현

 위와 같은 세부 실행은 Core 계층의 저장소와 데이터베이스 구현체가 담당하고,
 이 타입은 SearchEngine 초기화에 필요한 값과 정책을 안정적으로 보관하는 역할에 집중합니다.
 */
public struct SearchEngineConfiguration: Equatable, Sendable {
    /*
     SearchEngine 기본 디렉터리 이름입니다.
     */
    public static let defaultDirectoryName = "SearchEngine"

    /*
     SearchEngine 기본 SQLite 파일 이름입니다.
     */
    public static let defaultFileName = "SearchEngine.sqlite"

    /*
     SearchEngine 기본 busy timeout 값입니다.
     */
    public static let defaultBusyTimeoutMilliseconds: Int32 = 5_000

    /*
     SearchEngine 데이터베이스 저장 위치를 표현하는 값입니다.
     */
    public enum Storage: Equatable, Sendable {
        /*
         디스크 기반 SQLite 저장소입니다.
         */
        case sqlite(
            directoryName: String,
            fileName: String,
            baseDirectoryURL: URL?
        )

        /*
         메모리 기반 SQLite 저장소입니다.
         */
        case inMemory(identifier: String)
    }

    /*
     데이터베이스 저장 위치입니다.
     */
    public let storage: Storage

    /*
     데이터베이스 초기화 시 적용할 migration 계획입니다.
     */
    public let migrationPlan: SearchEngineMigrationPlan

    /*
     SQLite busy timeout 값입니다.
     */
    public let busyTimeoutMilliseconds: Int32

    /*
     WAL 모드 사용 여부입니다.
     */
    public let enablesWriteAheadLogging: Bool

    /*
     foreign key 사용 여부입니다.
     */
    public let enablesForeignKeys: Bool

    /*
     SearchEngineConfiguration을 생성합니다.

     Parameters:
     - storage: 데이터베이스 저장 위치
     - migrationPlan: 데이터베이스 초기화 시 적용할 migration 계획
     - busyTimeoutMilliseconds: SQLite busy timeout 값
     - enablesWriteAheadLogging: WAL 모드 사용 여부
     - enablesForeignKeys: foreign key 사용 여부
     */
    public init(
        storage: Storage,
        migrationPlan: SearchEngineMigrationPlan = .sqliteCore,
        busyTimeoutMilliseconds: Int32 = SearchEngineConfiguration.defaultBusyTimeoutMilliseconds,
        enablesWriteAheadLogging: Bool = true,
        enablesForeignKeys: Bool = true
    ) {
        self.storage = storage
        self.migrationPlan = migrationPlan
        self.busyTimeoutMilliseconds = busyTimeoutMilliseconds
        self.enablesWriteAheadLogging = enablesWriteAheadLogging
        self.enablesForeignKeys = enablesForeignKeys
    }

    /*
     디스크 기반 SQLite 저장소 구성을 생성합니다.

     기본 운영 환경에서 사용할 SearchEngine 설정을 간단히 만들 수 있는 편의 메서드입니다.
     경로 계산과 필수 문자열 검증을 먼저 수행하여,
     실제 데이터베이스 초기화 시 모호한 파일 시스템 오류를 줄입니다.

     Parameters:
     - directoryName: SQLite 파일을 저장할 디렉터리 이름
     - fileName: SQLite 파일 이름
     - baseDirectoryURL: 기준 디렉터리 URL
     - migrationPlan: 데이터베이스 초기화 시 적용할 migration 계획
     - busyTimeoutMilliseconds: SQLite busy timeout 값
     - enablesWriteAheadLogging: WAL 모드 사용 여부
     - enablesForeignKeys: foreign key 사용 여부

     Returns:
     - 디스크 기반 SearchEngineConfiguration

     Throws:
     - 구성 값이 잘못되었으면 에러를 던집니다.
     */
    public static func live(
        directoryName: String = SearchEngineConfiguration.defaultDirectoryName,
        fileName: String = SearchEngineConfiguration.defaultFileName,
        baseDirectoryURL: URL? = nil,
        migrationPlan: SearchEngineMigrationPlan = .sqliteCore,
        busyTimeoutMilliseconds: Int32 = SearchEngineConfiguration.defaultBusyTimeoutMilliseconds,
        enablesWriteAheadLogging: Bool = true,
        enablesForeignKeys: Bool = true
    ) throws -> SearchEngineConfiguration {
        let configuration = SearchEngineConfiguration(
            storage: .sqlite(
                directoryName: directoryName,
                fileName: fileName,
                baseDirectoryURL: baseDirectoryURL
            ),
            migrationPlan: migrationPlan,
            busyTimeoutMilliseconds: busyTimeoutMilliseconds,
            enablesWriteAheadLogging: enablesWriteAheadLogging,
            enablesForeignKeys: enablesForeignKeys
        )

        try configuration.validate()
        _ = try configuration.databaseURL()

        return configuration
    }

    /*
     메모리 기반 SQLite 저장소 구성을 생성합니다.

     빠른 샘플 실행, 테스트, 디스크 부작용 없는 확인 작업에 사용할 수 있는 편의 메서드입니다.

     Parameters:
     - identifier: in-memory 데이터베이스 식별자
     - migrationPlan: 데이터베이스 초기화 시 적용할 migration 계획
     - busyTimeoutMilliseconds: SQLite busy timeout 값
     - enablesWriteAheadLogging: WAL 모드 사용 여부
     - enablesForeignKeys: foreign key 사용 여부

     Returns:
     - 메모리 기반 SearchEngineConfiguration
     */
    public static func inMemory(
        identifier: String = "SearchEngine.InMemory",
        migrationPlan: SearchEngineMigrationPlan = .sqliteCore,
        busyTimeoutMilliseconds: Int32 = SearchEngineConfiguration.defaultBusyTimeoutMilliseconds,
        enablesWriteAheadLogging: Bool = false,
        enablesForeignKeys: Bool = true
    ) -> SearchEngineConfiguration {
        SearchEngineConfiguration(
            storage: .inMemory(identifier: identifier),
            migrationPlan: migrationPlan,
            busyTimeoutMilliseconds: busyTimeoutMilliseconds,
            enablesWriteAheadLogging: enablesWriteAheadLogging,
            enablesForeignKeys: enablesForeignKeys
        )
    }

    /*
     SQLite 데이터베이스 URL을 반환합니다.

     디스크 기반 저장소인 경우 실제 파일을 만들 위치를 계산해 반환하고,
     메모리 저장소인 경우 nil을 반환합니다.
     live 설정에서는 이 URL 계산 과정에서 부모 디렉터리도 함께 준비합니다.

     Returns:
     - SQLite 데이터베이스 URL 또는 nil

     Throws:
     - 디스크 경로를 구성할 수 없으면 에러를 던집니다.
     */
    public func databaseURL() throws -> URL? {
        switch storage {
        case let .sqlite(directoryName, fileName, baseDirectoryURL):
            let resolvedBaseDirectoryURL = try resolveBaseDirectoryURL(
                explicitBaseDirectoryURL: baseDirectoryURL
            )
            let directoryURL = resolvedBaseDirectoryURL
                .appendingPathComponent(directoryName, isDirectory: true)

            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            return directoryURL
                .appendingPathComponent(fileName, isDirectory: false)

        case .inMemory:
            return nil
        }
    }

    /*
     in-memory SQLite 연결 문자열을 반환합니다.

     Returns:
     - shared cache를 사용하는 in-memory SQLite URI 문자열

     Throws:
     - identifier가 유효하지 않으면 에러를 던집니다.
     */
    func inMemoryConnectionString() throws -> String {
        guard case let .inMemory(identifier) = storage else {
            throw SearchEngineError.invalidConfiguration(
                message: "inMemoryConnectionString is available only for in-memory storage."
            )
        }

        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedIdentifier = trimmedIdentifier.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? trimmedIdentifier

        return "file:\(encodedIdentifier)?mode=memory&cache=shared"
    }

    /*
     구성 값이 유효한지 검증합니다.

     Throws:
     - 구성 값이 잘못되었으면 에러를 던집니다.
     */
    public func validate() throws {
        try migrationPlan.validate()

        if busyTimeoutMilliseconds < 0 {
            throw SearchEngineError.invalidConfiguration(
                message: "busyTimeoutMilliseconds must be greater than or equal to zero."
            )
        }

        switch storage {
        case let .sqlite(directoryName, fileName, _):
            if directoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw SearchEngineError.invalidConfiguration(
                    message: "directoryName must not be empty."
                )
            }

            if fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw SearchEngineError.invalidConfiguration(
                    message: "fileName must not be empty."
                )
            }

        case let .inMemory(identifier):
            if identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw SearchEngineError.invalidConfiguration(
                    message: "identifier must not be empty."
                )
            }
        }
    }
}

private extension SearchEngineConfiguration {
    /*
     디스크 기반 저장소가 사용할 기준 디렉터리 URL을 결정합니다.

     Parameters:
     - explicitBaseDirectoryURL: 호출부가 명시적으로 전달한 기준 디렉터리 URL

     Returns:
     - 디스크 기반 SQLite 파일을 저장할 기준 디렉터리 URL

     Throws:
     - 기준 디렉터리를 찾을 수 없으면 에러를 던집니다.
     */
    func resolveBaseDirectoryURL(
        explicitBaseDirectoryURL: URL?
    ) throws -> URL {
        if let explicitBaseDirectoryURL {
            return explicitBaseDirectoryURL
        }

        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw SearchEngineError.databasePathUnavailable(
                message: "Unable to resolve applicationSupportDirectory URL."
            )
        }

        return applicationSupportURL
    }
}
