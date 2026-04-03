//
//  InMemorySQLiteStorage.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
@testable import SearchEngine

/*
 테스트 전용 in-memory SQLiteStorage 생성 도우미입니다.

 테스트에서는 디스크 기반 SQLite 저장소 대신 in-memory 저장소를 사용하여
 테스트 실행 속도를 높이고, 파일 생성이나 정리 작업 없이
 독립적인 실행 환경을 만들 수 있어야 합니다.

 이 타입은 SearchEngineConfiguration.inMemory를 감싼 테스트 진입점 역할을 하며,
 sqlite-core 단계의 foundation 동작을 공통된 방식으로 검증할 수 있게 돕습니다.
 */
enum InMemorySQLiteStorage {
    /*
     테스트용 in-memory SQLiteStorage를 생성합니다.

     Parameters:
     - identifier: in-memory 데이터베이스 식별자

     Returns:
     - 테스트에서 바로 사용할 수 있는 SQLiteStorageProtocol 구현 객체

     Throws:
     - SQLite foundation 초기화에 실패하면 에러를 던집니다.
     */
    static func make(
        identifier: String = UUID().uuidString
    ) throws -> SQLiteStorageProtocol {
        try SQLiteStorage(
            configuration: .inMemory(identifier: identifier)
        )
    }
}
