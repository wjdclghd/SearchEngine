//
//  InMemorySQLiteDatabase.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
@testable import SearchEngine

@testable import SearchEngine

/*
 테스트 전용 in-memory SQLiteDatabase 생성 도우미입니다.

 SQLite foundation의 가장 낮은 계층을 직접 검증해야 할 때,
 별도 디스크 파일 없이 독립적인 데이터베이스 연결을 빠르게 만들기 위해 사용합니다.
 */
enum InMemorySQLiteDatabase {
    /*
     테스트용 in-memory SQLiteDatabase를 생성합니다.

     Parameters:
     - identifier: in-memory 데이터베이스 식별자

     Returns:
     - 테스트에서 바로 사용할 수 있는 SQLiteDatabase 구현 객체

     Throws:
     - SQLite foundation 초기화에 실패하면 에러를 던집니다.
     */
    static func make(
        identifier: String = UUID().uuidString
    ) throws -> SQLiteDatabase {
        try SQLiteDatabase(
            configuration: .inMemory(identifier: identifier)
        )
    }
}
