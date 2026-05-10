//
//  SearchEngineContainer.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// SearchEngine 모듈의 조립 진입점입니다.
public final class SearchEngineContainer {
    private let sqliteStorage: SQLiteStorageProtocol

    /// 컨테이너 생성에 사용된 설정값입니다.
    public let configuration: SearchEngineConfiguration

    private init(
        configuration: SearchEngineConfiguration,
        sqliteStorage: SQLiteStorageProtocol
    ) {
        self.configuration = configuration
        self.sqliteStorage = sqliteStorage
    }

    /// 지정한 설정으로 SearchEngineContainer를 생성합니다.
    ///
    /// - Parameter configuration: 저장소 종류, SQLite 정책, 경로 정보를 포함한 설정값입니다.
    ///
    /// - Returns: 사용할 준비가 완료된 SearchEngineContainer입니다.
    ///
    /// - Throws: 설정값 검증, 데이터베이스 경로 생성, SQLite 초기화에 실패하면 에러를 던집니다.
    public static func make(
        configuration: SearchEngineConfiguration
    ) throws -> SearchEngineContainer {
        let sqliteStorage = try SQLiteStorage(configuration: configuration)

        return SearchEngineContainer(
            configuration: configuration,
            sqliteStorage: sqliteStorage
        )
    }

    /// 기본 SQLite 저장소를 사용하는 컨테이너를 생성합니다.
    ///
    /// - Returns: 기본 live 설정으로 초기화된 SearchEngineContainer입니다.
    ///
    /// - Throws: 기본 설정 생성 또는 SQLite 초기화에 실패하면 에러를 던집니다.
    public static func makeDefault() throws -> SearchEngineContainer {
        try make(configuration: .live())
    }

    /// 기본 in-memory SQLite 저장소를 사용하는 컨테이너를 생성합니다.
    ///
    /// - Returns: 기본 in-memory 설정으로 초기화된 SearchEngineContainer입니다.
    ///
    /// - Throws: SQLite 초기화 실패 시 에러를 던집니다.
    public static func makeDefaultInMemory() throws -> SearchEngineContainer {
        try make(configuration: .inMemory())
    }

    /// 현재 컨테이너 설정으로 공개 SearchEngine 계약 구현체를 생성합니다.
    ///
    /// - Returns: `SearchEngineProtocol`을 구현하는 검색 엔진 객체입니다.
    public func makeSearchEngine() -> some SearchEngineProtocol {
        SQLiteSearchEngine(
            documentStore: makeSQLiteSearchDocumentStore(),
            searchStore: makeSQLiteSearchStore(),
            suggestionStore: makeSQLiteSearchSuggestionStore(),
            rebuilder: makeSearchRebuilder()
        )
    }

    /// 현재 컨테이너가 보관 중인 SQLite 저장 기반을 반환합니다.
    ///
    /// - Returns: SearchEngine 내부에서 사용할 SQLite 저장 기반 구현체입니다.
    func makeSQLiteStorage() -> SQLiteStorageProtocol {
        sqliteStorage
    }

    /// SQLite 기반 문서 색인 Store를 생성합니다.
    ///
    /// - Returns: 현재 컨테이너 저장 기반으로 조립된 문서 Store입니다.
    func makeSQLiteSearchDocumentStore() -> SQLiteSearchDocumentStore {
        SQLiteSearchDocumentStore(storage: sqliteStorage)
    }

    /// SQLite 기반 검색 Store를 생성합니다.
    ///
    /// - Returns: 현재 컨테이너 저장 기반으로 조립된 검색 Store입니다.
    func makeSQLiteSearchStore() -> SQLiteSearchStore {
        SQLiteSearchStore(storage: sqliteStorage)
    }

    /// SQLite 기반 자동완성 Store를 생성합니다.
    ///
    /// - Returns: 현재 컨테이너 저장 기반으로 조립된 자동완성 Store입니다.
    func makeSQLiteSearchSuggestionStore() -> SQLiteSearchSuggestionStore {
        SQLiteSearchSuggestionStore(storage: sqliteStorage)
    }

    /// 저장된 문서 기준으로 FTS projection을 재구성하는 객체를 생성합니다.
    ///
    /// - Returns: 현재 컨테이너 저장 기반으로 조립된 SearchRebuilder입니다.
    func makeSearchRebuilder() -> SearchRebuilder {
        SearchRebuilder(storage: sqliteStorage)
    }
}
