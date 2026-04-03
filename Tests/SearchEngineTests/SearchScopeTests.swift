//
//  SearchScopeTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchScope의 기본 값 동작을 확인하는 테스트입니다.

 SearchScope는 검색 범위를 감싸는 가장 작은 공개 값 타입이므로,
 문자열 리터럴 초기화와 공백 정규화 같은 기초 동작이 흔들리지 않아야
 이후 문서/질의 검증 로직도 안정적으로 유지할 수 있습니다.
 */
final class SearchScopeTests: XCTestCase {
    /*
     문자열 리터럴로 SearchScope를 생성할 수 있는지 검증합니다.
     */
    func test_stringLiteralInitializesRawValue() {
        let scope: SearchScope = "app"
        XCTAssertEqual(scope.rawValue, "app")
    }

    /*
     공백만 있는 범위는 빈 값으로 판단되는지 검증합니다.
     */
    func test_isEmpty_withWhitespaceOnlyScope_returnsTrue() {
        let scope = SearchScope(rawValue: "   ")
        XCTAssertTrue(scope.isEmpty)
    }

    /*
     앞뒤 공백이 있어도 정규화 값이 올바르게 계산되는지 검증합니다.
     */
    func test_normalizedValue_trimsWhitespace() {
        let scope = SearchScope(rawValue: "  app.scope  ")
        XCTAssertEqual(scope.normalizedValue, "app.scope")
    }
}
