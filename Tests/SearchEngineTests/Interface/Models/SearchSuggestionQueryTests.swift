//
//  SearchSuggestionQueryTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SearchSuggestionQuery의 검증 동작을 확인하는 테스트입니다.
final class SearchSuggestionQueryTests: XCTestCase {
    func test_validate_withEmptyText_throwsInvalidQuery() {
        // given / when
        let query = SearchSuggestionQuery(text: "   ")

        // then
        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withEmptyScope_throwsInvalidQuery() {
        // given / when
        let query = SearchSuggestionQuery(
            text: "swift",
            scope: SearchScope(rawValue: "  ")
        )

        // then
        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withNonPositiveLimit_throwsInvalidQuery() {
        // given / when
        let query = SearchSuggestionQuery(text: "swift", limit: 0)

        // then
        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withLimitGreaterThanMaximum_throwsInvalidQuery() {
        // given / when
        let query = SearchSuggestionQuery(
            text: "swift",
            limit: SearchSuggestionQuery.maximumLimit + 1
        )

        // then
        XCTAssertThrowsError(try query.validate()) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withValidQuery_succeeds() {
        // given / when
        let query = SearchSuggestionQuery(
            text: "swift",
            scope: SearchScope(rawValue: "app"),
            limit: 10
        )

        // then
        XCTAssertNoThrow(try query.validate())
    }
}
