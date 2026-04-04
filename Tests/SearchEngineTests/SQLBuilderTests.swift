//
//  SQLBuilderTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SQLBuilder의 기본 SQL 조립 동작을 확인하는 테스트입니다.

 복잡한 검색 SQL 대신
 공통 조립 유틸이 일관된 문자열을 생성하는지 먼저 검증해두면,
 Querying 계층에서 조건 조합이 늘어나더라도 foundation 신뢰도를 유지할 수 있습니다.
 */
final class SQLBuilderTests: XCTestCase {
    /*
     placeholder 개수만큼 쉼표 구분 문자열이 생성되는지 검증합니다.
     */
    func test_placeholders_createsExpectedString() {
        XCTAssertEqual(SQLBuilder.placeholders(count: 3), "?, ?, ?")
    }

    /*
     assignmentList가 컬럼 목록을 SQL assignment 형식으로 조합하는지 검증합니다.
     */
    func test_assignmentList_createsExpectedString() {
        XCTAssertEqual(
            SQLBuilder.assignmentList(columns: ["title", "body"]),
            "title = ?, body = ?"
        )
    }

    /*
     정렬 기준이 없으면 빈 ORDER BY 절을 반환하는지 검증합니다.
     */
    func test_orderBy_withEmptyClauses_returnsEmptyString() {
        XCTAssertEqual(SQLBuilder.orderBy(clauses: []), "")
    }

    /*
     정렬 기준이 있으면 ORDER BY 절이 예상한 문자열로 생성되는지 검증합니다.
     */
    func test_orderBy_withClauses_createsExpectedString() {
        let clauses = [
            SQLBuilder.SortClause(column: "updated_at", direction: .descending),
            SQLBuilder.SortClause(column: "title", direction: .ascending)
        ]

        XCTAssertEqual(
            SQLBuilder.orderBy(clauses: clauses),
            "ORDER BY updated_at DESC, title ASC"
        )
    }


    /*
     placeholder 개수가 0 이하이면 빈 문자열을 반환하는지 검증합니다.
     */
    func test_placeholders_withZeroCount_returnsEmptyString() {
        XCTAssertEqual(SQLBuilder.placeholders(count: 0), "")
    }

    /*
     assignmentList에 컬럼이 없으면 빈 문자열을 반환하는지 검증합니다.
     */
    func test_assignmentList_withEmptyColumns_returnsEmptyString() {
        XCTAssertEqual(SQLBuilder.assignmentList(columns: []), "")
    }

}
