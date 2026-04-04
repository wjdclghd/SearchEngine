//
//  SearchSuggestionQueryTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchSuggestionQuery의 검증 동작을 확인하는 테스트입니다.

 제안 생성 이전에 빈 입력값, 범위 오류, 잘못된 limit가 차단되면,
 이후 Suggest 계층에서 불필요한 방어 로직을 줄일 수 있습니다.
 */
final class SearchSuggestionQueryTests: XCTestCase {
    /*
     입력 문자열이 비어 있는 SearchSuggestionQuery는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_validate_withEmptyText_throwsInvalidQuery() {
        let query = SearchSuggestionQuery(text: "   ")

        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     scope가 비어 있는 SearchSuggestionQuery는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_validate_withEmptyScope_throwsInvalidQuery() {
        let query = SearchSuggestionQuery(
            text: "swift",
            scope: SearchScope(rawValue: "  ")
        )

        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     limit이 0 이하인 SearchSuggestionQuery는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_validate_withNonPositiveLimit_throwsInvalidQuery() {
        let query = SearchSuggestionQuery(text: "swift", limit: 0)

        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     유효한 SearchSuggestionQuery는 검증을 통과하는지 검증합니다.
     */
    func test_validate_withValidQuery_succeeds() {
        let query = SearchSuggestionQuery(
            text: "swift",
            scope: SearchScope(rawValue: "app"),
            limit: 10
        )

        XCTAssertNoThrow(try query.validate())
    }
}
