//
//  SearchMatchQueryBuilder.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/// SearchQuery와 suggestion 입력을 SQLite FTS MATCH 문자열로 변환하는 보조 유틸리티입니다.
///
/// SearchEngine 외부에서는 단순 문자열 질의를 사용하지만,
/// SQLite FTS5는 MATCH 문법에 맞는 문자열이 필요합니다.
/// 이 타입은 입력 문자열을 토큰 단위로 정리하고,
/// prefix 검색이 가능한 MATCH 쿼리 문자열로 안전하게 조립하는 역할을 담당합니다.
enum SearchMatchQueryBuilder {
    /// SearchQuery를 MATCH 문자열로 변환합니다.
    ///
    /// - Parameter query: MATCH 문자열로 변환할 검색 질의입니다.
    ///
    /// - Returns: SQLite FTS MATCH 문법에 맞는 질의 문자열입니다.
    ///
    /// - Throws: 유효한 검색 토큰을 만들 수 없으면 invalidQuery를 던집니다.
    static func buildMatchQuery(
        from query: SearchQuery
    ) throws -> String {
        try buildMatchQuery(from: query.text)
    }

    /// 특정 FTS 컬럼만 대상으로 하는 MATCH 문자열을 생성합니다.
    ///
    /// 특정 컬럼만 검색해야 하는 Store 구현에서 사용할 수 있도록,
    /// column scoped MATCH 문법을 별도로 조립합니다.
    ///
    /// - Parameter text: MATCH 문자열로 변환할 입력 문자열입니다.
    /// - Parameter columnName: 대상 FTS 컬럼 이름입니다.
    ///
    /// - Returns: 지정한 컬럼에만 적용되는 SQLite FTS MATCH 문자열입니다.
    ///
    /// - Throws: 유효한 검색 토큰을 만들 수 없거나 컬럼 이름이 올바르지 않으면 invalidQuery를 던집니다.
    static func buildColumnScopedMatchQuery(
        from text: String,
        columnName: String
    ) throws -> String {
        let normalizedColumnName = columnName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedColumnName.isEmpty == false,
              normalizedColumnName.range(
                of: "^[A-Za-z_][A-Za-z0-9_]*$",
                options: .regularExpression
              ) != nil else {
            throw SearchEngineError.invalidQuery(
                message: "columnName must be a valid FTS column identifier."
            )
        }

        let tokens = try normalizedTokensOrThrow(from: text)

        return tokens
            .map { token in
                let escapedToken = token.replacingOccurrences(of: "\"", with: "\"\"")
                return "\(normalizedColumnName):\"\(escapedToken)\"*"
            }
            .joined(separator: " AND ")
    }
}

private extension SearchMatchQueryBuilder {
    /// 일반 검색용 MATCH 문자열을 생성합니다.
    static func buildMatchQuery(from text: String) throws -> String {
        let tokens = try normalizedTokensOrThrow(from: text)

        return tokens
            .map { token in
                let escapedToken = token.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escapedToken)\"*"
            }
            .joined(separator: " AND ")
    }

    /// 입력 문자열에서 검색 가능한 토큰 목록을 추출하고 비어 있지 않은지 검증합니다.
    static func normalizedTokensOrThrow(from text: String) throws -> [String] {
        let tokens = normalizedTokens(from: text)

        if tokens.isEmpty {
            throw SearchEngineError.invalidQuery(
                message: "text must contain at least one searchable token."
            )
        }

        return tokens
    }

    /// 입력 문자열에서 검색 가능한 토큰 목록을 추출합니다.
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
