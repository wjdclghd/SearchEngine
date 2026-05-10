//
//  SQLiteStorageProtocol.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation
import SQLite3

/// SearchEngine 내부에서 SQLite 저장 기반을 추상화하는 계약입니다.
protocol SQLiteStorageProtocol {
    /// 저장 기반 생성에 사용된 설정값입니다.
    var configuration: SearchEngineConfiguration { get }

    /// SQL 한 문장을 직접 실행합니다.
    ///
    /// - Parameter sql: 실행할 SQL 문자열입니다.
    ///
    /// - Throws: SQL 실행에 실패하면 에러를 던집니다.
    func execute(sql: String) throws

    /// 읽기 작업을 수행합니다.
    ///
    /// - Parameter operation: SQLite 연결 포인터를 받아 읽기 작업을 수행하는 클로저입니다.
    ///
    /// - Returns: 읽기 작업 결과 값입니다.
    ///
    /// - Throws: 읽기 작업에 실패하면 에러를 던집니다.
    func read<T>(_ operation: (OpaquePointer) throws -> T) throws -> T

    /// 쓰기 작업을 수행합니다.
    ///
    /// - Parameter operation: SQLite 연결 포인터를 받아 쓰기 작업을 수행하는 클로저입니다.
    ///
    /// - Returns: 쓰기 작업 결과 값입니다.
    ///
    /// - Throws: 쓰기 작업에 실패하면 에러를 던집니다.
    func write<T>(_ operation: (OpaquePointer) throws -> T) throws -> T

    /// 트랜잭션 안에서 작업을 수행합니다.
    ///
    /// - Parameter operation: SQLite 연결 포인터를 받아 트랜잭션 작업을 수행하는 클로저입니다.
    ///
    /// - Returns: 트랜잭션 작업 결과 값입니다.
    ///
    /// - Throws: 트랜잭션 실행에 실패하면 에러를 던집니다.
    func transaction<T>(_ operation: (OpaquePointer) throws -> T) throws -> T
}
