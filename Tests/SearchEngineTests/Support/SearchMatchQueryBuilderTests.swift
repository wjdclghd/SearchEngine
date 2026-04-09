//
//  SearchMatchQueryBuilderTests.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchMatchQueryBuilder의 MATCH 질의 조립 규칙을 확인하는 테스트입니다.

 Search 실행기와 Suggest 구현체는 사용자 입력 문자열을 그대로 SQL에 넣지 않고
 FTS MATCH 문법에 맞는 토큰 문자열로 변환해야 합니다.
 이 테스트는 토큰 정규화, prefix 검색, column scoped query, 잘못된 입력 차단 규칙을 검증합니다.
 */
final class SearchMatchQueryBuilderTests: XCTestCase {
    /*
     공백과 구두점이 섞인 질의도 토큰 단위로 정규화되어 MATCH 문자열이 생성되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_buildMatchQuery_normalizesTokensAndBuildsPrefixQuery() throws {
        let query = SearchQuery(text: "  swift,   sqlite! fts5  ")

        let matchQuery = try SearchMatchQueryBuilder.buildMatchQuery(from: query)

        XCTAssertEqual(matchQuery, "\"swift\"* AND \"sqlite\"* AND \"fts5\"*")
    }

    /*
     검색 가능한 토큰을 만들 수 없으면 invalidQuery를 반환하는지 검증합니다.
     */
    func test_buildMatchQuery_withNoSearchableToken_throwsInvalidQuery() {
        let query = SearchQuery(text: " !!! ??? ")

        XCTAssertThrowsError(try SearchMatchQueryBuilder.buildMatchQuery(from: query)) { error in
            guard case let SearchEngineError.invalidQuery(message) = error else {
                return XCTFail("Expected invalidQuery, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     여러 토큰 입력이 AND 결합된 prefix MATCH 문자열로 조립되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_buildMatchQuery_buildsAndJoinedPrefixTokens() throws {
        let query = SearchQuery(text: "swift sqlite tutorial")

        let matchQuery = try SearchMatchQueryBuilder.buildMatchQuery(from: query)

        XCTAssertEqual(matchQuery, "\"swift\"* AND \"sqlite\"* AND \"tutorial\"*")
    }

    /*
     큰따옴표가 포함된 입력은 MATCH 문법에 맞게 escape 되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_buildMatchQuery_escapesDoubleQuoteInToken() throws {
        let query = SearchQuery(text: "swift s\"qlite")

        let matchQuery = try SearchMatchQueryBuilder.buildMatchQuery(from: query)

        XCTAssertEqual(matchQuery, "\"swift\"* AND \"s\"\"qlite\"*")
    }

    /*
     column scoped FTS MATCH 질의가 정상적으로 생성되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_buildColumnScopedMatchQuery_withValidTokens_returnsScopedQuery() throws {
        let matchQuery = try SearchMatchQueryBuilder.buildColumnScopedMatchQuery(
            from: "swift sea",
            columnName: "title"
        )

        XCTAssertEqual(matchQuery, #"title:"swift"* AND title:"sea"*"#)
    }

    /*
     columnName이 비어 있으면 invalidQuery를 반환하는지 검증합니다.
     */
    func test_buildColumnScopedMatchQuery_withEmptyColumnName_throwsInvalidQuery() {
        XCTAssertThrowsError(
            try SearchMatchQueryBuilder.buildColumnScopedMatchQuery(
                from: "swift",
                columnName: ""
            )
        ) { error in
            XCTAssertEqual(
                error as? SearchEngineError,
                .invalidQuery(message: "columnName must be a valid FTS column identifier.")
            )
        }
    }

    /*
     유효하지 않은 columnName이 전달되면 invalidQuery를 반환하는지 검증합니다.
     */
    func test_buildColumnScopedMatchQuery_withInvalidColumnName_throwsInvalidQuery() {
        XCTAssertThrowsError(
            try SearchMatchQueryBuilder.buildColumnScopedMatchQuery(
                from: "swift",
                columnName: "title-name"
            )
        ) { error in
            XCTAssertEqual(
                error as? SearchEngineError,
                .invalidQuery(message: "columnName must be a valid FTS column identifier.")
            )
        }
    }

    /*
     column scoped token에 큰따옴표가 포함된 경우 escape 처리되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_buildColumnScopedMatchQuery_withQuotedToken_escapesDoubleQuotes() throws {
        let matchQuery = try SearchMatchQueryBuilder.buildColumnScopedMatchQuery(
            from: #"swift "engine""#,
            columnName: "title"
        )

        XCTAssertEqual(matchQuery, #"title:"swift"* AND title:"""engine"""*"#)
    }
}
