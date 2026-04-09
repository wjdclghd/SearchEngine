//
//  SearchSuggestionTests.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchSuggestion 공개 모델의 기본 동작을 확인하는 테스트입니다.

 SearchSuggestion은 자동완성 결과를 상위 계층으로 전달하는 값 타입이므로,
 생성 시 전달한 text, scope, score가 그대로 유지되어야 합니다.
 */
final class SearchSuggestionTests: XCTestCase {
    /*
     SearchSuggestion이 생성자 입력값을 그대로 보관하는지 검증합니다.
     */
    func test_init_storesProvidedValues() {
        let suggestion = SearchSuggestion(
            text: "Swift Search",
            scope: SearchScope(rawValue: "app.notice"),
            score: 320
        )

        XCTAssertEqual(suggestion.text, "Swift Search")
        XCTAssertEqual(suggestion.scope, SearchScope(rawValue: "app.notice"))
        XCTAssertEqual(suggestion.score, 320)
    }

    /*
     scope 없이 생성한 SearchSuggestion도 정상적으로 표현되는지 검증합니다.
     */
    func test_init_withNilScope_storesNilScope() {
        let suggestion = SearchSuggestion(
            text: "Swift Search",
            scope: nil,
            score: 120
        )

        XCTAssertEqual(suggestion.text, "Swift Search")
        XCTAssertNil(suggestion.scope)
        XCTAssertEqual(suggestion.score, 120)
    }
}
