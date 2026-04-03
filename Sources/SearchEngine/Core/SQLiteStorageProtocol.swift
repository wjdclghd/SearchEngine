//
//  SQLiteStorageProtocol.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation
import SQLite3

/*
 SearchEngine 내부에서 SQLite 기반 저장 foundation을 추상화하는 계약입니다.

 이후 색인기, 검색 실행기, 제안 생성기는 이 프로토콜을 통해
 공통 읽기/쓰기/트랜잭션 경로를 사용합니다.
 구체 데이터베이스 연결 관리와 pragma 적용은 하위 SQLiteDatabase가 담당하고,
 이 프로토콜은 SearchEngine 내부 공통 실행 진입점을 정리하는 역할을 맡습니다.
 */
protocol SQLiteStorageProtocol {
    /*
     저장 foundation 생성에 사용된 설정값입니다.
     */
    var configuration: SearchEngineConfiguration { get }

    /*
     SQL 한 문장을 직접 실행합니다.

     Parameters:
     - sql: 실행할 SQL 문자열

     Throws:
     - SQL 실행에 실패하면 에러를 던집니다.
     */
    func execute(sql: String) throws

    /*
     읽기 작업을 수행합니다.

     Parameters:
     - operation: SQLite 연결 포인터를 받아 읽기 작업을 수행하는 클로저

     Returns:
     - 읽기 작업 결과 값

     Throws:
     - 읽기 작업에 실패하면 에러를 던집니다.
     */
    func read<T>(_ operation: (OpaquePointer) throws -> T) throws -> T

    /*
     쓰기 작업을 수행합니다.

     Parameters:
     - operation: SQLite 연결 포인터를 받아 쓰기 작업을 수행하는 클로저

     Returns:
     - 쓰기 작업 결과 값

     Throws:
     - 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func write<T>(_ operation: (OpaquePointer) throws -> T) throws -> T

    /*
     트랜잭션 안에서 작업을 수행합니다.

     Parameters:
     - operation: SQLite 연결 포인터를 받아 트랜잭션 작업을 수행하는 클로저

     Returns:
     - 트랜잭션 작업 결과 값

     Throws:
     - 트랜잭션 실행에 실패하면 에러를 던집니다.
     */
    func transaction<T>(_ operation: (OpaquePointer) throws -> T) throws -> T
}
