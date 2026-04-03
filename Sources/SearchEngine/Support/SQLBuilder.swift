//
//  SQLBuilder.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 동적 SQL 문자열을 조립할 때 사용하는 보조 유틸리티입니다.

 복잡한 쿼리 작성은 이후 검색 실행기와 제안 생성기에서 다루게 되므로,
 sqlite-core 단계에서는 공통적으로 자주 쓰는 조립 기능만 제공합니다.
 SQLBuilder는 public API가 아니라 모듈 내부 구현 보조 역할에 집중하며,
 SearchEngine 외부에는 raw SQL 조립 세부사항을 노출하지 않습니다.
 */
enum SQLBuilder {
    /*
     정렬 방향을 표현하는 값입니다.
     */
    enum SortDirection: String, Sendable {
        /*
         오름차순 정렬입니다.
         */
        case ascending = "ASC"

        /*
         내림차순 정렬입니다.
         */
        case descending = "DESC"
    }

    /*
     정렬 기준 한 건을 표현하는 값입니다.
     */
    struct SortClause: Equatable, Sendable {
        /*
         정렬에 사용할 컬럼 이름입니다.
         */
        let column: String

        /*
         정렬 방향입니다.
         */
        let direction: SortDirection

        /*
         SortClause를 생성합니다.

         Parameters:
         - column: 정렬에 사용할 컬럼 이름
         - direction: 정렬 방향
         */
        init(
            column: String,
            direction: SortDirection
        ) {
            self.column = column
            self.direction = direction
        }
    }

    /*
     전달한 개수만큼 placeholder 문자열을 생성합니다.

     Parameters:
     - count: 생성할 placeholder 개수

     Returns:
     - 쉼표로 연결된 placeholder 문자열
     */
    static func placeholders(count: Int) -> String {
        guard count > 0 else {
            return ""
        }

        return Array(repeating: "?", count: count).joined(separator: ", ")
    }

    /*
     전달한 컬럼 목록으로 assignment 문자열을 생성합니다.

     Parameters:
     - columns: assignment에 사용할 컬럼 목록

     Returns:
     - "column = ?" 형식의 assignment 문자열
     */
    static func assignmentList(columns: [String]) -> String {
        columns
            .map { "\($0) = ?" }
            .joined(separator: ", ")
    }

    /*
     전달한 정렬 기준 목록으로 ORDER BY 절을 생성합니다.

     Parameters:
     - clauses: 정렬 기준 목록

     Returns:
     - ORDER BY 절 문자열 또는 빈 문자열
     */
    static func orderBy(clauses: [SortClause]) -> String {
        guard clauses.isEmpty == false else {
            return ""
        }

        let joinedClauses = clauses
            .map { "\($0.column) \($0.direction.rawValue)" }
            .joined(separator: ", ")

        return "ORDER BY \(joinedClauses)"
    }
}
