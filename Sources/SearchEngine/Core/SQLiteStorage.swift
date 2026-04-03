//
//  SQLiteStorage.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation
import SQLite3

/*
 SearchEngine 모듈의 SQLite 기반 저장 foundation 구현체입니다.

 이 타입은 SearchEngine이 SQLite를 사용할 수 있도록 foundation을 구성하고,
 상위 내부 계층이 안전한 방식으로 읽기, 쓰기, 트랜잭션 경로를 사용할 수 있게 공통 실행 진입점을 제공합니다.

 담당 역할
 - SearchEngineConfiguration 기반 SQLite foundation 생성
 - 공통 읽기/쓰기/트랜잭션 경로 제공
 - 이후 Indexing, Querying 계층이 재사용할 실행 기반 제공

 담당하지 않는 역할
 - FTS 스키마 생성
 - 문서별 색인 규칙 구성
 - 검색 결과 점수 계산
 - 제안 문자열 생성

 위와 같은 세부 검색 로직은 이후 계층에서 담당하고,
 이 타입은 저장 foundation을 안정적으로 실행하는 공통 기반에 집중합니다.
 */
final class SQLiteStorage: SQLiteStorageProtocol {
    private let database: SQLiteDatabaseProtocol

    /*
     저장 foundation 생성에 사용된 설정값입니다.
     */
    let configuration: SearchEngineConfiguration

    init(configuration: SearchEngineConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration
        self.database = try SQLiteDatabase(configuration: configuration)
    }

    /*
     테스트나 특수 조립 경로에서 주입형 데이터베이스를 사용할 수 있는 내부 초기화 메서드입니다.

     Parameters:
     - configuration: 저장 foundation 생성에 사용된 설정값
     - database: 주입할 SQLiteDatabaseProtocol 구현 객체
     */
    init(
        configuration: SearchEngineConfiguration,
        database: SQLiteDatabaseProtocol
    ) {
        self.configuration = configuration
        self.database = database
    }

    /*
     SQL 한 문장을 직접 실행합니다.

     Parameters:
     - sql: 실행할 SQL 문자열

     Throws:
     - SQL 실행에 실패하면 에러를 던집니다.
     */
    func execute(sql: String) throws {
        try database.execute(sql: sql)
    }

    /*
     읽기 작업을 수행합니다.

     Parameters:
     - operation: SQLite 연결 포인터를 받아 읽기 작업을 수행하는 클로저

     Returns:
     - 읽기 작업 결과 값

     Throws:
     - 읽기 작업에 실패하면 에러를 던집니다.
     */
    func read<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try database.read(operation)
    }

    /*
     쓰기 작업을 수행합니다.

     Parameters:
     - operation: SQLite 연결 포인터를 받아 쓰기 작업을 수행하는 클로저

     Returns:
     - 쓰기 작업 결과 값

     Throws:
     - 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func write<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try database.write(operation)
    }

    /*
     트랜잭션 안에서 작업을 수행합니다.

     Parameters:
     - operation: SQLite 연결 포인터를 받아 트랜잭션 작업을 수행하는 클로저

     Returns:
     - 트랜잭션 작업 결과 값

     Throws:
     - 트랜잭션 실행에 실패하면 에러를 던집니다.
     */
    func transaction<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try database.transaction(operation)
    }
}
