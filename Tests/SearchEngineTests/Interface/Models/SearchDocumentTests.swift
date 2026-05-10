//
//  SearchDocumentTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SearchDocument의 검증 동작을 확인하는 테스트입니다.
final class SearchDocumentTests: XCTestCase {
    func test_validate_withEmptyID_throwsInvalidDocument() {
        // given / when
        let document = SearchDocument(
            id: " ",
            scope: SearchScope(rawValue: "app"),
            title: "SwiftUI",
            body: "Body",
            lastUpdatedAt: Date()
        )

        // then
        XCTAssertThrowsError(try document.validate()) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withEmptyScope_throwsInvalidDocument() {
        // given / when
        let document = SearchDocument(
            id: "document-1",
            scope: SearchScope(rawValue: "   "),
            title: "SwiftUI",
            body: "Body",
            lastUpdatedAt: Date()
        )

        // then
        XCTAssertThrowsError(try document.validate()) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withEmptyTitleAndBody_throwsInvalidDocument() {
        // given / when
        let document = SearchDocument(
            id: "document-1",
            scope: SearchScope(rawValue: "app"),
            title: " ",
            body: " ",
            lastUpdatedAt: Date()
        )

        // then
        XCTAssertThrowsError(try document.validate()) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withValidDocument_succeeds() {
        // given / when
        let document = SearchDocument(
            id: "document-1",
            scope: SearchScope(rawValue: "app"),
            title: "SwiftUI",
            body: "Combine Architecture",
            keywords: ["ios", "swift"],
            lastUpdatedAt: Date()
        )

        // then
        XCTAssertNoThrow(try document.validate())
    }
}
