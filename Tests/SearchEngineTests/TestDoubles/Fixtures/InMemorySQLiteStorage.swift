//
//  InMemorySQLiteStorage.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
@testable import SearchEngine

/// 테스트 전용 in-memory SQLiteStorage 생성 도우미입니다.
enum InMemorySQLiteStorage {
    /// 테스트용 in-memory SQLiteStorage를 생성합니다.
    ///
    /// - Parameter identifier: in-memory 데이터베이스 식별자입니다.
    ///
    /// - Returns: 테스트에서 바로 사용할 수 있는 SQLiteStorageProtocol 구현 객체입니다.
    ///
    /// - Throws: SQLite 기반 초기화에 실패하면 에러를 던집니다.
    static func make(
        identifier: String = UUID().uuidString
    ) throws -> SQLiteStorageProtocol {
        try SQLiteStorage(
            configuration: .inMemory(identifier: identifier)
        )
    }
}
