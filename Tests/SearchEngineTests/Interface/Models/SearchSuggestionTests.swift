//
//  SearchSuggestionTests.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/// SearchSuggestion 공개 모델의 기본 동작을 확인하는 테스트입니다.
///
/// SearchSuggestion은 자동완성 결과를 상위 계층으로 전달하는 값 타입이므로,
/// 생성 시 전달한 표시 문자열, 범위, 점수, metadata가 그대로 유지되어야 합니다.
final class SearchSuggestionTests: XCTestCase {

    func test_init_storesProvidedValues() {
        // given / when
        let suggestion = SearchSuggestion(
            text: "Swift Search",
            scope: SearchScope(rawValue: "app.notice"),
            score: 320
        )

        // then
        XCTAssertEqual(suggestion.text, "Swift Search")
        XCTAssertEqual(suggestion.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertEqual(suggestion.score, 320)
        XCTAssertEqual(suggestion.source, .title)
        XCTAssertEqual(suggestion.kind, .query)
        XCTAssertNil(suggestion.documentID)
        XCTAssertNil(suggestion.matchedText)
    }

    func test_init_withNilScope_storesNilScope() {
        // given / when
        let suggestion = SearchSuggestion(
            text: "Swift Search",
            scope: nil,
            score: 120
        )

        // then
        XCTAssertEqual(suggestion.text, "Swift Search")
        XCTAssertNil(suggestion.scope)
        XCTAssertEqual(suggestion.score, 120)
    }

    func test_init_withMetadata_storesProvidedValues() {
        // given / when
        let suggestion = SearchSuggestion(
            text: "Music",
            scope: SearchScope(rawValue: "appstore.autocomplete"),
            score: 180,
            source: .keyword,
            kind: .document,
            documentID: "appstore.track.1",
            matchedText: "music"
        )

        // then
        XCTAssertEqual(suggestion.text, "Music")
        XCTAssertEqual(suggestion.scope, SearchScope(rawValue: "appstore.autocomplete"))
        XCTAssertEqual(suggestion.score, 180)
        XCTAssertEqual(suggestion.source, .keyword)
        XCTAssertEqual(suggestion.kind, .document)
        XCTAssertEqual(suggestion.documentID, "appstore.track.1")
        XCTAssertEqual(suggestion.matchedText, "music")
    }
}
