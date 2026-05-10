//
//  SQLiteStorage.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation
import SQLite3

/// SearchEngine 모듈의 SQLite 저장 기반 구현체입니다.
final class SQLiteStorage: SQLiteStorageProtocol {
    private let database: SQLiteDatabaseProtocol

    /// 저장 기반 생성에 사용된 설정값입니다.
    let configuration: SearchEngineConfiguration

    init(configuration: SearchEngineConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration
        self.database = try SQLiteDatabase(configuration: configuration)
    }

    /// 테스트나 특수 조립 경로에서 주입형 데이터베이스를 사용할 수 있는 내부 초기화 메서드입니다.
    ///
    /// - Parameter configuration: 저장 기반 생성에 사용된 설정값입니다.
    /// - Parameter database: 주입할 SQLiteDatabaseProtocol 구현 객체입니다.
    init(
        configuration: SearchEngineConfiguration,
        database: SQLiteDatabaseProtocol
    ) {
        self.configuration = configuration
        self.database = database
    }

    func execute(sql: String) throws {
        try database.execute(sql: sql)
    }

    func read<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try database.read(operation)
    }

    func write<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try database.write(operation)
    }

    func transaction<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        try database.transaction(operation)
    }
}
