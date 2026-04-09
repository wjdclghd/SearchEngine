//
//  SearchEngineContainer.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 SearchEngine 모듈의 조립 진입점입니다.

 앱 또는 상위 모듈은 이 타입을 통해 SearchEngine foundation을 초기화합니다.
 컨테이너는 검색 엔진 초기화에 필요한 설정과 SQLite 기반 저장 foundation을 보관하고,
 이후 문서 저장 구현체, 검색 실행기, 제안 생성기 같은 기능 객체를 구성하는 기반 역할을 담당합니다.

 아직 공개 엔진 구현체를 직접 생성하지 않지만,
 동일한 초기화 흐름 위에 기능 조립을 확장할 수 있도록 컨테이너 구조를 먼저 마련합니다.
 */
public final class SearchEngineContainer {
    private let sqliteStorage: SQLiteStorageProtocol

    /*
     컨테이너 생성에 사용된 설정값입니다.

     어떤 저장소 종류와 SQLite 정책으로 초기화되었는지 확인해야 할 때 참조할 수 있습니다.
     */
    public let configuration: SearchEngineConfiguration

    private init(
        configuration: SearchEngineConfiguration,
        sqliteStorage: SQLiteStorageProtocol
    ) {
        self.configuration = configuration
        self.sqliteStorage = sqliteStorage
    }

    /*
     지정한 설정으로 SearchEngineContainer를 생성합니다.

     이 메서드는 외부에서 SearchEngine 모듈을 초기화할 때 사용하는 기본 진입점입니다.
     내부적으로 설정값 검증과 SQLite foundation 준비를 완료한 뒤,
     준비된 컨테이너를 반환합니다.

     Parameters:
     - configuration: 저장소 종류, SQLite 정책, 경로 정보를 포함한 설정값

     Returns:
     - 사용할 준비가 완료된 SearchEngineContainer

     Throws:
     - 설정값 검증 실패
     - 데이터베이스 경로 생성 실패
     - SQLite 초기화 실패
     */
    public static func make(
        configuration: SearchEngineConfiguration
    ) throws -> SearchEngineContainer {
        let sqliteStorage = try SQLiteStorage(configuration: configuration)

        return SearchEngineContainer(
            configuration: configuration,
            sqliteStorage: sqliteStorage
        )
    }

    /*
     기본 SQLite 저장소를 사용하는 컨테이너를 생성합니다.

     운영 환경에서 기본 SearchEngine 설정으로 빠르게 초기화하고 싶을 때 사용할 수 있는 편의 메서드입니다.

     Returns:
     - 기본 live 설정으로 초기화된 SearchEngineContainer

     Throws:
     - 기본 설정 생성 실패
     - SQLite 초기화 실패
     */
    public static func makeDefault() throws -> SearchEngineContainer {
        try make(configuration: .live())
    }

    /*
     기본 in-memory SQLite 저장소를 사용하는 컨테이너를 생성합니다.

     디스크 파일 없이 SearchEngine foundation을 빠르게 확인하거나,
     테스트 보조 용도로 사용할 수 있는 편의 메서드입니다.

     Returns:
     - 기본 in-memory 설정으로 초기화된 SearchEngineContainer

     Throws:
     - SQLite 초기화 실패
     */
    public static func makeDefaultInMemory() throws -> SearchEngineContainer {
        try make(configuration: .inMemory())
    }

    /*
     현재 컨테이너가 보관 중인 SQLite 저장 foundation을 반환합니다.

     현재는 SearchEngine 공개 구현체 대신
     내부 저장 foundation을 기반으로 테스트와 기능 조립을 진행합니다.

     Returns:
     - SearchEngine 내부에서 사용할 SQLite 저장 foundation 구현체
     */
    func makeSQLiteStorage() -> SQLiteStorageProtocol {
        sqliteStorage
    }

    /*
     현재 컨테이너 설정으로 SQLiteSearchDocumentStore를 생성합니다.

     문서 저장과 삭제 기능은 같은 SQLite foundation 위에서 동작해야 하므로,
     컨테이너는 공통 저장 foundation을 재사용하는 Store 구현체 조립 진입점도 함께 제공합니다.

     Returns:
     - 현재 컨테이너 기반으로 조립된 SQLiteSearchDocumentStore
     */
    func makeSQLiteSearchDocumentStore() -> SQLiteSearchDocumentStore {
        SQLiteSearchDocumentStore(storage: sqliteStorage)
    }

    /*
     현재 컨테이너 설정으로 SQLiteSearchStore를 생성합니다.

     검색 실행 구현체도 같은 SQLite foundation과 migration 기준 위에서 동작해야 하므로,
     컨테이너는 검색 Store 조립 진입점도 함께 제공합니다.

     Returns:
     - 현재 컨테이너 기반으로 조립된 SQLiteSearchStore
     */
    func makeSQLiteSearchStore() -> SQLiteSearchStore {
        SQLiteSearchStore(storage: sqliteStorage)
    }

    /*
     현재 컨테이너 설정으로 SQLiteSearchSuggestionStore를 생성합니다.

     자동완성 구현체도 같은 SQLite foundation과 migration 기준 위에서 동작해야 하므로,
     컨테이너는 suggestion Store 조립 진입점도 함께 제공합니다.

     Returns:
     - 현재 컨테이너 기반으로 조립된 SQLiteSearchSuggestionStore
     */
    func makeSQLiteSearchSuggestionStore() -> SQLiteSearchSuggestionStore {
        SQLiteSearchSuggestionStore(storage: sqliteStorage)
    }

    /*
     현재 컨테이너 설정으로 SearchRebuilder를 생성합니다.

     projection rebuild 구현체도 같은 SQLite foundation과 migration 기준 위에서 동작해야 하므로,
     컨테이너는 복구용 rebuild 조립 진입점도 함께 제공합니다.

     Returns:
     - 현재 컨테이너 기반으로 조립된 SearchRebuilder
     */
    func makeSearchRebuilder() -> SearchRebuilder {
        SearchRebuilder(storage: sqliteStorage)
    }
}
