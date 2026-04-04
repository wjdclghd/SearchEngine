//
//  SearchMatchQueryBuilder.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/*
 SearchQuery를 SQLite FTS MATCH 문자열로 변환하는 보조 유틸리티입니다.

 SearchEngine 외부에서는 단순 문자열 질의를 사용하지만,
 SQLite FTS5는 MATCH 문법에 맞는 문자열이 필요합니다.
 이 타입은 입력 문자열을 토큰 단위로 정리하고,
 prefix 검색이 가능한 MATCH 쿼리 문자열로 안전하게 조립하는 역할을 담당합니다.
 */
enum SearchMatchQueryBuilder {
    /*
     SearchQuery를 MATCH 문자열로 변환합니다.

     Parameters:
     - query: MATCH 문자열로 변환할 검색 질의

     Returns:
     - SQLite FTS MATCH 문법에 맞는 질의 문자열

     Throws:
     - 유효한 검색 토큰을 만들 수 없으면 invalidQuery를 던집니다.
     */
    static func buildMatchQuery(
        from query: SearchQuery
    ) throws -> String {
        let tokens = normalizedTokens(from: query.text)

        if tokens.isEmpty {
            throw SearchEngineError.invalidQuery(
                message: "text must contain at least one searchable token."
            )
        }

        return tokens
            .map { token in
                let escapedToken = token.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escapedToken)\"*"
            }
            .joined(separator: " AND ")
    }
}

private extension SearchMatchQueryBuilder {
    /*
     입력 문자열에서 검색 가능한 토큰 목록을 추출합니다.

     Parameters:
     - text: 토큰을 추출할 입력 문자열

     Returns:
     - 공백, 구두점, 제어 문자를 정리한 검색 토큰 목록
     */
    static func normalizedTokens(from text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(
                CharacterSet.punctuationCharacters.subtracting(
                    CharacterSet(charactersIn: "\"")
                )
            )
            .union(.controlCharacters)
            .union(.symbols)

        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
