//
//  SQLiteSearchSuggestionStore.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation
import SQLite3

/// SearchSuggestionQuery를 SQLite FTS5 기반 자동완성 질의로 실행하는 Store 구현체입니다.
final class SQLiteSearchSuggestionStore {
    private let storage: SQLiteStorageProtocol

    /// SQLiteSearchSuggestionStore를 생성합니다.
    ///
    /// - Parameter storage: 자동완성 질의 실행에 사용할 SQLite 기반입니다.
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /// 자동완성 질의를 실행하고 suggestion 목록을 반환합니다.
    ///
    /// - Parameter query: 실행할 자동완성 질의입니다.
    ///
    /// - Returns: 자동완성 화면에 노출할 suggestion 목록입니다.
    ///
    /// - Throws: 질의 검증 실패 또는 SQLite suggestion 실행 실패 시 에러를 던집니다.
    func suggest(_ query: SearchSuggestionQuery) throws -> [SearchSuggestion] {
        try query.validate()

        let normalizedInput = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchQuery = try SearchMatchQueryBuilder.buildMatchQuery(from: SearchQuery(text: normalizedInput))
        let exactPattern = normalizedInput
        let prefixPattern = "\(normalizedInput)%"
        let containsPattern = "%\(normalizedInput)%"
        let sql = Self.suggestSQL(hasScopeFilter: query.scope != nil)

        return try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(sql: sql, in: databasePointer)
            defer { SQLiteDatabase.finalizeStatement(statement) }

            var bindingIndex: Int32 = 1
            try SQLiteDatabase.bind(exactPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(prefixPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(containsPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(containsPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(containsPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(exactPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(prefixPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(containsPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(containsPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(containsPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(matchQuery, to: statement, index: bindingIndex)
            bindingIndex += 1

            if let scope = query.scope {
                try SQLiteDatabase.bind(scope.normalizedValue, to: statement, index: bindingIndex)
                bindingIndex += 1
            }

            try SQLiteDatabase.bind(query.limit, to: statement, index: bindingIndex)

            var suggestions: [SearchSuggestion] = []

            while true {
                let stepResult = sqlite3_step(statement)

                if stepResult == SQLITE_DONE {
                    break
                }

                guard stepResult == SQLITE_ROW else {
                    throw SearchEngineError.statementExecutionFailed(
                        sql: sql,
                        message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                    )
                }

                let record = try Self.makeSearchSuggestionRecord(from: statement)
                suggestions.append(
                    SearchSuggestionMapper.toSearchSuggestion(
                        SearchSuggestionRecord(
                            text: record.text,
                            scope: record.scope,
                            score: record.score,
                            source: record.source,
                            kind: record.kind,
                            documentID: record.documentID,
                            matchedText: normalizedInput
                        )
                    )
                )
            }

            return suggestions
        }
    }
}

private extension SQLiteSearchSuggestionStore {
    /// 범위 필터 포함 여부에 따라 suggestion SQL을 생성합니다.
    ///
    /// - Parameter hasScopeFilter: 범위 필터 적용 여부입니다.
    ///
    /// - Returns: 실행할 suggestion SQL 문자열입니다.
    static func suggestSQL(hasScopeFilter: Bool) -> String {
        let scopeCondition = hasScopeFilter ? "              AND d.scope = ?" : ""
        let orderByClause = SQLBuilder.orderBy(
            clauses: [
                .init(column: "score", direction: .descending),
                .init(column: "latest_updated_at", direction: .descending),
                .init(column: "suggestion_text", direction: .ascending)
            ]
        )

        return """
        WITH suggestion_candidates AS (
            SELECT
                TRIM(d.title) AS normalized_title,
                LOWER(TRIM(d.title)) AS normalized_title_key,
                d.scope AS suggestion_scope,
                d.id AS suggestion_document_id,
                CASE
                    WHEN TRIM(d.title) = ? COLLATE NOCASE THEN 400
                    WHEN TRIM(d.title) LIKE ? COLLATE NOCASE THEN 300
                    WHEN TRIM(d.title) LIKE ? COLLATE NOCASE THEN 200
                    WHEN d.keywords LIKE ? COLLATE NOCASE THEN 180
                    WHEN d.body LIKE ? COLLATE NOCASE THEN 140
                    ELSE 100
                END AS base_score,
                CASE
                    WHEN TRIM(d.title) = ? COLLATE NOCASE THEN 'title'
                    WHEN TRIM(d.title) LIKE ? COLLATE NOCASE THEN 'title'
                    WHEN TRIM(d.title) LIKE ? COLLATE NOCASE THEN 'title'
                    WHEN d.keywords LIKE ? COLLATE NOCASE THEN 'keyword'
                    WHEN d.body LIKE ? COLLATE NOCASE THEN 'body'
                    ELSE 'title'
                END AS suggestion_source,
                d.last_updated_at AS last_updated_at
            FROM \(SearchEngineMigrationSQL.documentsFTSTableName)
            JOIN \(SearchEngineMigrationSQL.documentsTableName) AS d
                ON d.id = \(SearchEngineMigrationSQL.documentsFTSTableName).id
            WHERE \(SearchEngineMigrationSQL.documentsFTSTableName) MATCH ?
              AND TRIM(d.title) <> ''
            \(scopeCondition)
        ),
        ranked_suggestions AS (
            SELECT
                normalized_title,
                normalized_title_key,
                suggestion_scope,
                suggestion_document_id,
                suggestion_source,
                base_score,
                COUNT(*) OVER (
                    PARTITION BY normalized_title_key, suggestion_scope
                ) AS duplicate_count,
                MAX(last_updated_at) OVER (
                    PARTITION BY normalized_title_key, suggestion_scope
                ) AS latest_updated_at,
                ROW_NUMBER() OVER (
                    PARTITION BY normalized_title_key, suggestion_scope
                    ORDER BY base_score DESC, last_updated_at DESC, normalized_title ASC
                ) AS row_number
            FROM suggestion_candidates
        )
        SELECT
            normalized_title AS suggestion_text,
            suggestion_scope,
            suggestion_document_id,
            suggestion_source,
            'document' AS suggestion_kind,
            (base_score + duplicate_count * 10) AS score,
            latest_updated_at
        FROM ranked_suggestions
        WHERE row_number = 1
        \(orderByClause)
        LIMIT ?;
        """
    }

    /// SQLite suggestion 결과 한 행을 SearchSuggestion Record로 복원합니다.
    ///
    /// - Parameter statement: 현재 행을 가리키는 SQLite statement입니다.
    ///
    /// - Returns: Mapper 계층으로 전달할 SearchSuggestion Record입니다.
    ///
    /// - Throws: 필수 컬럼을 문자열로 읽지 못하면 에러를 던집니다.
    static func makeSearchSuggestionRecord(
        from statement: OpaquePointer
    ) throws -> SearchSuggestionRecord {
        SearchSuggestionRecord(
            text: try SQLiteDatabase.readRequiredText(from: statement, column: 0, columnName: "suggestion_text", sql: "SELECT search suggestions"),
            scope: SQLiteDatabase.readOptionalText(from: statement, column: 1),
            score: Int(sqlite3_column_int(statement, 5)),
            source: try readSuggestionSource(from: statement, column: 3),
            kind: try readSuggestionKind(from: statement, column: 4),
            documentID: SQLiteDatabase.readOptionalText(from: statement, column: 2)
        )
    }

    /// suggestion source 컬럼을 공개 enum 값으로 복원합니다.
    ///
    /// - Parameter statement: 값을 읽을 SQLite statement입니다.
    /// - Parameter column: 읽을 컬럼 인덱스입니다.
    ///
    /// - Returns: 복원된 SearchSuggestionSource 값입니다.
    ///
    /// - Throws: 알 수 없는 source 값이면 statementExecutionFailed를 던집니다.
    static func readSuggestionSource(
        from statement: OpaquePointer,
        column: Int32
    ) throws -> SearchSuggestionSource {
        let rawValue = try SQLiteDatabase.readRequiredText(from: statement, column: column, columnName: "suggestion_source", sql: "SELECT search suggestions")

        guard let source = SearchSuggestionSource(rawValue: rawValue) else {
            throw SearchEngineError.statementExecutionFailed(
                sql: "SELECT search suggestions",
                message: "Invalid suggestion source: \(rawValue)."
            )
        }

        return source
    }

    /// suggestion kind 컬럼을 공개 enum 값으로 복원합니다.
    ///
    /// - Parameter statement: 값을 읽을 SQLite statement입니다.
    /// - Parameter column: 읽을 컬럼 인덱스입니다.
    ///
    /// - Returns: 복원된 SearchSuggestionKind 값입니다.
    ///
    /// - Throws: 알 수 없는 kind 값이면 statementExecutionFailed를 던집니다.
    static func readSuggestionKind(
        from statement: OpaquePointer,
        column: Int32
    ) throws -> SearchSuggestionKind {
        let rawValue = try SQLiteDatabase.readRequiredText(from: statement, column: column, columnName: "suggestion_kind", sql: "SELECT search suggestions")

        guard let kind = SearchSuggestionKind(rawValue: rawValue) else {
            throw SearchEngineError.statementExecutionFailed(
                sql: "SELECT search suggestions",
                message: "Invalid suggestion kind: \(rawValue)."
            )
        }

        return kind
    }

}
