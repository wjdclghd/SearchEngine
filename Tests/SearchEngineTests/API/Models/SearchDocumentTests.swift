//
//  SearchDocumentTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchDocument의 검증 동작을 확인하는 테스트입니다.

 공개 문서 모델에서 잘못된 값이 미리 차단되면,
 이후 Indexing 계층에서 불필요한 방어 분기를 줄이고
 오류 원인을 더 명확하게 전달할 수 있습니다.
 */
final class SearchDocumentTests: XCTestCase {
    /*
     id가 비어 있는 문서는 invalidDocument를 반환하는지 검증합니다.
     */
    func test_validate_withEmptyID_throwsInvalidDocument() {
        let document = SearchDocument(
            id: " ",
            scope: SearchScope(rawValue: "app"),
            title: "SwiftUI",
            body: "Body",
            lastUpdatedAt: Date()
        )

        XCTAssertThrowsError(try document.validate()) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     scope가 비어 있는 문서는 invalidDocument를 반환하는지 검증합니다.
     */
    func test_validate_withEmptyScope_throwsInvalidDocument() {
        let document = SearchDocument(
            id: "document-1",
            scope: SearchScope(rawValue: "   "),
            title: "SwiftUI",
            body: "Body",
            lastUpdatedAt: Date()
        )

        XCTAssertThrowsError(try document.validate()) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     제목과 본문이 모두 비어 있는 문서는 invalidDocument를 반환하는지 검증합니다.
     */
    func test_validate_withEmptyTitleAndBody_throwsInvalidDocument() {
        let document = SearchDocument(
            id: "document-1",
            scope: SearchScope(rawValue: "app"),
            title: " ",
            body: " ",
            lastUpdatedAt: Date()
        )

        XCTAssertThrowsError(try document.validate()) { error in
            guard case let SearchEngineError.invalidDocument(message) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     유효한 문서는 검증을 통과하는지 검증합니다.
     */
    func test_validate_withValidDocument_succeeds() {
        let document = SearchDocument(
            id: "document-1",
            scope: SearchScope(rawValue: "app"),
            title: "SwiftUI",
            body: "Combine Architecture",
            keywords: ["ios", "swift"],
            lastUpdatedAt: Date()
        )

        XCTAssertNoThrow(try document.validate())
    }
}
