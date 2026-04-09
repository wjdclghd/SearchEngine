//
//  SearchQueryTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchQuery의 검증 동작을 확인하는 테스트입니다.

 검색 실행 이전에 빈 검색어, 범위 오류, 잘못된 페이지네이션 값이 차단되면,
 이후 Querying 계층에서 SQL 조합을 단순하게 유지할 수 있습니다.
 */
final class SearchQueryTests: XCTestCase {
    /*
     검색어가 비어 있는 SearchQuery는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_validate_withEmptyText_throwsInvalidQuery() {
        let query = SearchQuery(text: "   ")

        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     scope가 비어 있는 SearchQuery는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_validate_withEmptyScope_throwsInvalidQuery() {
        let query = SearchQuery(
            text: "swift",
            scope: SearchScope(rawValue: " ")
        )

        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     limit이 0 이하인 SearchQuery는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_validate_withNonPositiveLimit_throwsInvalidQuery() {
        let query = SearchQuery(text: "swift", limit: 0)

        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     offset이 음수인 SearchQuery는 invalidQuery를 반환하는지 검증합니다.
     */
    func test_validate_withNegativeOffset_throwsInvalidQuery() {
        let query = SearchQuery(text: "swift", offset: -1)

        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     유효한 SearchQuery는 검증을 통과하는지 검증합니다.
     */
    func test_validate_withValidQuery_succeeds() {
        let query = SearchQuery(
            text: "swift",
            scope: SearchScope(rawValue: "app"),
            limit: 20,
            offset: 0
        )

        XCTAssertNoThrow(try query.validate())
    }
}
