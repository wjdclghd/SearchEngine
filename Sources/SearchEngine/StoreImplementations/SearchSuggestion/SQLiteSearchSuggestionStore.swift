//
//  SQLiteSearchSuggestionStore.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation
import SQLite3

/*
 SearchSuggestionQuery를 SQLite FTS5 기반 title 자동완성 질의로 실행하는 Store 구현체입니다.

 이 타입은 문서 원본과 FTS projection을 사용해 title 컬럼 기준 suggestion 후보를 조회하고,
 자동완성 화면에 바로 사용할 수 있는 SearchSuggestion 목록으로 복원합니다.
 현재 Suggest 단계의 책임은 title 기반 검색 자동완성에 한정하며,
 body 또는 keywords 기반 추천 검색어 생성과는 책임을 분리합니다.
 */
final class SQLiteSearchSuggestionStore {
    private let storage: SQLiteStorageProtocol

    /*
     SQLiteSearchSuggestionStore를 생성합니다.

     Parameters:
     - storage: 자동완성 질의 실행에 사용할 SQLite foundation
     */
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /*
     자동완성 질의를 실행하고 suggestion 목록을 반환합니다.

     Parameters:
     - query: 실행할 자동완성 질의

     Returns:
     - 자동완성 화면에 노출할 suggestion 목록

     Throws:
     - 질의 검증 실패 또는 SQLite suggestion 실행 실패 시 에러를 던집니다.
     */
    func suggest(_ query: SearchSuggestionQuery) throws -> [SearchSuggestion] {
        try query.validate()

        let normalizedInput = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleScopedMatchQuery = try SearchMatchQueryBuilder.buildColumnScopedMatchQuery(
            from: normalizedInput,
            columnName: "title"
        )
        let exactPattern = normalizedInput
        let prefixPattern = "\(normalizedInput)%"
        let containsPattern = "%\(normalizedInput)%"
        let sql = Self.suggestSQL(hasScopeFilter: query.scope != nil)

        return try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(sql: sql, in: databasePointer)
            defer { SQLiteDatabase.finalizeStatement(statement) }

            var bindingIndex: Int32 = 1
            try Self.bind(exactPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try Self.bind(prefixPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try Self.bind(containsPattern, to: statement, index: bindingIndex)
            bindingIndex += 1
            try Self.bind(titleScopedMatchQuery, to: statement, index: bindingIndex)
            bindingIndex += 1

            if let scope = query.scope {
                try Self.bind(scope.normalizedValue, to: statement, index: bindingIndex)
                bindingIndex += 1
            }

            try Self.bind(query.limit, to: statement, index: bindingIndex)

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

                let managedObject = try Self.makeSearchSuggestionManagedObject(from: statement)
                suggestions.append(SearchSuggestionMapper.toSearchSuggestion(managedObject))
            }

            return suggestions
        }
    }
}

private extension SQLiteSearchSuggestionStore {
    /*
     범위 필터 포함 여부에 따라 suggestion SQL을 생성합니다.

     Parameters:
     - hasScopeFilter: 범위 필터 적용 여부

     Returns:
     - 실행할 suggestion SQL 문자열
     */
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
                CASE
                    WHEN TRIM(d.title) = ? COLLATE NOCASE THEN 400
                    WHEN TRIM(d.title) LIKE ? COLLATE NOCASE THEN 300
                    WHEN TRIM(d.title) LIKE ? COLLATE NOCASE THEN 200
                    ELSE 100
                END AS base_score,
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
                base_score,
                COUNT(*) OVER (
                    PARTITION BY normalized_title_key, suggestion_scope
                ) AS duplicate_count,
                MAX(last_updated_at) OVER (
                    PARTITION BY normalized_title_key, suggestion_scope
                ) AS latest_updated_at,
                ROW_NUMBER() OVER (
                    PARTITION BY normalized_title_key, suggestion_scope
                    ORDER BY last_updated_at DESC, normalized_title ASC
                ) AS row_number
            FROM suggestion_candidates
        )
        SELECT
            normalized_title AS suggestion_text,
            suggestion_scope,
            (base_score + duplicate_count * 10) AS score,
            latest_updated_at
        FROM ranked_suggestions
        WHERE row_number = 1
        \(orderByClause)
        LIMIT ?;
        """
    }

    /*
     SQLite suggestion 결과 한 행을 SearchSuggestion ManagedObject로 복원합니다.

     Parameters:
     - statement: 현재 행을 가리키는 SQLite statement

     Returns:
     - Mapper 계층으로 전달할 SearchSuggestion ManagedObject

     Throws:
     - 필수 컬럼을 문자열로 읽지 못하면 에러를 던집니다.
     */
    static func makeSearchSuggestionManagedObject(
        from statement: OpaquePointer
    ) throws -> SearchSuggestionMO {
        SearchSuggestionMO(
            text: try readRequiredText(from: statement, column: 0, columnName: "suggestion_text"),
            scope: readOptionalText(from: statement, column: 1),
            score: Int(sqlite3_column_int(statement, 2))
        )
    }

    /*
     필수 문자열 컬럼을 읽습니다.

     Parameters:
     - statement: 값을 읽을 SQLite statement
     - column: 읽을 컬럼 인덱스
     - columnName: 오류 메시지에 사용할 컬럼 이름

     Returns:
     - 읽은 문자열 값

     Throws:
     - 문자열 컬럼을 읽지 못하면 statementExecutionFailed를 던집니다.
     */
    static func readRequiredText(
        from statement: OpaquePointer,
        column: Int32,
        columnName: String
    ) throws -> String {
        guard let cString = sqlite3_column_text(statement, column) else {
            throw SearchEngineError.statementExecutionFailed(
                sql: "SELECT search suggestions",
                message: "Missing required text column: \(columnName)."
            )
        }

        return String(cString: cString)
    }

    /*
     선택 문자열 컬럼을 읽습니다.

     Parameters:
     - statement: 값을 읽을 SQLite statement
     - column: 읽을 컬럼 인덱스

     Returns:
     - 읽은 문자열 값 또는 nil
     */
    static func readOptionalText(
        from statement: OpaquePointer,
        column: Int32
    ) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else {
            return nil
        }

        return String(cString: cString)
    }

    /*
     문자열 값을 SQLite parameter에 바인딩합니다.

     Parameters:
     - value: 바인딩할 문자열 값
     - statement: 값을 바인딩할 SQLite statement
     - index: parameter 인덱스

     Throws:
     - 바인딩에 실패하면 statementBindingFailed를 던집니다.
     */
    static func bind(
        _ value: String,
        to statement: OpaquePointer,
        index: Int32
    ) throws {
        let result = value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransientDestructor)
        }

        guard result == SQLITE_OK else {
            throw SearchEngineError.statementBindingFailed(
                index: index,
                message: "Failed to bind text parameter."
            )
        }
    }

    /*
     정수 값을 SQLite parameter에 바인딩합니다.

     Parameters:
     - value: 바인딩할 정수 값
     - statement: 값을 바인딩할 SQLite statement
     - index: parameter 인덱스

     Throws:
     - 바인딩에 실패하면 statementBindingFailed를 던집니다.
     */
    static func bind(
        _ value: Int,
        to statement: OpaquePointer,
        index: Int32
    ) throws {
        let result = sqlite3_bind_int64(statement, index, sqlite3_int64(value))

        guard result == SQLITE_OK else {
            throw SearchEngineError.statementBindingFailed(
                index: index,
                message: "Failed to bind integer parameter."
            )
        }
    }

    /*
     SQLite 문자열 바인딩에서 사용할 transient destructor입니다.
     */
    static var sqliteTransientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
