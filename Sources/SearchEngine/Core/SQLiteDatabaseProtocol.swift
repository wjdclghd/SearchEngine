//
//  SQLiteDatabaseProtocol.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation
import SQLite3

/*
 SearchEngine 내부에서 SQLite 데이터베이스 접근을 추상화하는 계약입니다.

 SQLiteStorage는 이 프로토콜을 통해 읽기, 쓰기, 트랜잭션 실행을 수행하며,
 구체 연결 관리와 오류 매핑은 SQLiteDatabase가 담당합니다.
 OpaquePointer 기반 저수준 계약은 모듈 내부에만 두어,
 SearchEngine 외부 API에 SQLite 세부 구현이 노출되지 않도록 유지합니다.
 */
protocol SQLiteDatabaseProtocol {
    /*
     데이터베이스 구성 값입니다.
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
