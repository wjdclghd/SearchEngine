//
//  SearchSuggestionMapperTests.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SearchSuggestionMapper의 변환 동작을 확인하는 테스트입니다.
///
/// 제안 결과는 scope가 선택 값이고, 화면 노출 문자열은 불필요한 공백이 정리된 값이어야 하므로
/// SQLite 결과를 공개 API 모델로 변환하는 마지막 단계의 정규화 규칙을 검증합니다.
final class SearchSuggestionMapperTests: XCTestCase {
    /// scope 문자열이 존재하면 SearchScope로 복원되는지 검증합니다.
    func test_toSearchSuggestion_withScope_returnsSuggestionWithScope() {
        let record = SearchSuggestionRecord(
            text: "Swift Search",
            scope: "app.notice",
            score: 320
        )

        let suggestion = SearchSuggestionMapper.toSearchSuggestion(record)

        XCTAssertEqual(suggestion.text, "Swift Search")
        XCTAssertEqual(suggestion.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertEqual(suggestion.score, 320)
        XCTAssertEqual(suggestion.source, .title)
        XCTAssertEqual(suggestion.kind, .query)
        XCTAssertNil(suggestion.documentID)
        XCTAssertNil(suggestion.matchedText)
    }

    /// 공백만 있는 scope 문자열은 nil로 정리되는지 검증합니다.
    func test_toSearchSuggestion_withBlankScope_returnsSuggestionWithoutScope() {
        let record = SearchSuggestionRecord(
            text: "Swift Search",
            scope: "   ",
            score: 100
        )

        let suggestion = SearchSuggestionMapper.toSearchSuggestion(record)

        XCTAssertEqual(suggestion.text, "Swift Search")
        XCTAssertNil(suggestion.scope)
        XCTAssertEqual(suggestion.score, 100)
    }

    /// text 양쪽 공백이 제거된 뒤 반환되는지 검증합니다.
    func test_toSearchSuggestion_trimsTextBeforeReturning() {
        let record = SearchSuggestionRecord(
            text: "  Swift Search  ",
            scope: nil,
            score: 210
        )

        let suggestion = SearchSuggestionMapper.toSearchSuggestion(record)

        XCTAssertEqual(suggestion.text, "Swift Search")
        XCTAssertNil(suggestion.scope)
        XCTAssertEqual(suggestion.score, 210)
    }

    /// suggestion metadata가 공개 모델로 함께 전달되는지 검증합니다.
    func test_toSearchSuggestion_mapsMetadataFields() {
        let record = SearchSuggestionRecord(
            text: "Music",
            scope: "appstore.autocomplete",
            score: 180,
            source: .keyword,
            kind: .document,
            documentID: " appstore.track.1 ",
            matchedText: " music "
        )

        let suggestion = SearchSuggestionMapper.toSearchSuggestion(record)

        XCTAssertEqual(suggestion.text, "Music")
        XCTAssertEqual(suggestion.scope, SearchScope(rawValue: "appstore.autocomplete"))
        XCTAssertEqual(suggestion.score, 180)
        XCTAssertEqual(suggestion.source, .keyword)
        XCTAssertEqual(suggestion.kind, .document)
        XCTAssertEqual(suggestion.documentID, "appstore.track.1")
        XCTAssertEqual(suggestion.matchedText, "music")
    }
}
