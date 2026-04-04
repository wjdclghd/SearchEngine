//
//  SQLiteSearchStore.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3

/*
 SearchQuery를 SQLite FTS5 질의로 실행하는 Store 구현체입니다.

 이 타입은 SearchDocumentStore가 준비한 원본 문서 테이블과 FTS projection을 사용해
 검색 결과를 조회하고, 점수와 스니펫을 포함한 SearchHit 목록으로 복원합니다.
 Query 유효성 검증, MATCH 문자열 조립, 범위 필터링, 페이지네이션을 한 곳에 모아
 이후 상위 엔진 구현이 안정적인 검색 실행 경로를 재사용할 수 있도록 돕습니다.
 */
final class SQLiteSearchStore {
    private let storage: SQLiteStorageProtocol

    private static let titleSnippetStartMarker = "<b>"
    private static let titleSnippetEndMarker = "</b>"
    private static let bodySnippetStartMarker = "<b>"
    private static let bodySnippetEndMarker = "</b>"
    private static let snippetEllipsis = "…"

    /*
     SQLiteSearchStore를 생성합니다.

     Parameters:
     - storage: 검색 실행에 사용할 SQLite foundation
     */
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /*
     SearchQuery를 실행해 검색 결과 목록을 반환합니다.

     Parameters:
     - query: 실행할 검색 질의

     Returns:
     - 검색 결과 목록

     Throws:
     - 질의 검증 실패 또는 SQLite 검색 실행 실패 시 에러를 던집니다.
     */
    func search(_ query: SearchQuery) throws -> [SearchHit] {
        try query.validate()

        let matchQuery = try SearchMatchQueryBuilder.buildMatchQuery(from: query)
        let sql = Self.searchSQL(hasScopeFilter: query.scope != nil)

        return try storage.read { databasePointer in
            let statement = try Self.prepareStatement(sql: sql, in: databasePointer)
            defer { Self.finalizeStatement(statement) }

            var bindingIndex: Int32 = 1
            try Self.bind(matchQuery, to: statement, index: bindingIndex)
            bindingIndex += 1

            if let scope = query.scope {
                try Self.bind(scope.normalizedValue, to: statement, index: bindingIndex)
                bindingIndex += 1
            }

            try Self.bind(query.limit, to: statement, index: bindingIndex)
            bindingIndex += 1
            try Self.bind(query.offset, to: statement, index: bindingIndex)

            var hits: [SearchHit] = []

            while true {
                let stepResult = sqlite3_step(statement)

                if stepResult == SQLITE_DONE {
                    break
                }

                guard stepResult == SQLITE_ROW else {
                    throw SearchEngineError.statementExecutionFailed(
                        sql: sql,
                        message: Self.lastErrorMessage(from: databasePointer)
                    )
                }

                let managedObject = try Self.makeSearchHitManagedObject(from: statement)
                hits.append(SearchHitMapper.toSearchHit(managedObject))
            }

            return hits
        }
    }
}

private extension SQLiteSearchStore {
    /*
     범위 필터 포함 여부에 따라 검색 SQL을 생성합니다.

     Parameters:
     - hasScopeFilter: 범위 필터 적용 여부

     Returns:
     - 실행할 검색 SQL 문자열
     */
    static func searchSQL(hasScopeFilter: Bool) -> String {
        let scopeCondition = hasScopeFilter ? "AND d.scope = ?" : ""
        let orderByClause = SQLBuilder.orderBy(
            clauses: [
                .init(column: "score", direction: .ascending),
                .init(column: "d.last_updated_at", direction: .descending)
            ]
        )

        return """
        SELECT
            d.id,
            d.scope,
            d.title,
            d.body,
            d.keywords,
            d.last_updated_at,
            bm25(\(SearchEngineMigrationSQL.documentsFTSTableName)) AS score,
            snippet(\(SearchEngineMigrationSQL.documentsFTSTableName), 2, '\(titleSnippetStartMarker)', '\(titleSnippetEndMarker)', '\(snippetEllipsis)', 8) AS title_snippet,
            snippet(\(SearchEngineMigrationSQL.documentsFTSTableName), 3, '\(bodySnippetStartMarker)', '\(bodySnippetEndMarker)', '\(snippetEllipsis)', 16) AS body_snippet
        FROM \(SearchEngineMigrationSQL.documentsFTSTableName)
        JOIN \(SearchEngineMigrationSQL.documentsTableName) AS d
            ON d.id = \(SearchEngineMigrationSQL.documentsFTSTableName).id
        WHERE \(SearchEngineMigrationSQL.documentsFTSTableName) MATCH ?
        \(scopeCondition)
        \(orderByClause)
        LIMIT ? OFFSET ?;
        """
    }

    /*
     SQLite 검색 결과 한 행을 SearchHit ManagedObject로 복원합니다.

     Parameters:
     - statement: 현재 행을 가리키는 SQLite statement

     Returns:
     - Mapper 계층으로 전달할 SearchHit ManagedObject

     Throws:
     - 필수 컬럼을 문자열로 읽지 못하면 에러를 던집니다.
     */
    static func makeSearchHitManagedObject(
        from statement: OpaquePointer
    ) throws -> SearchHitMO {
        SearchHitMO(
            id: try readRequiredText(from: statement, column: 0, columnName: "id"),
            scope: try readRequiredText(from: statement, column: 1, columnName: "scope"),
            title: try readRequiredText(from: statement, column: 2, columnName: "title"),
            body: try readRequiredText(from: statement, column: 3, columnName: "body"),
            keywords: try readRequiredText(from: statement, column: 4, columnName: "keywords"),
            lastUpdatedAt: sqlite3_column_double(statement, 5),
            score: sqlite3_column_double(statement, 6),
            titleSnippet: readOptionalText(from: statement, column: 7),
            bodySnippet: readOptionalText(from: statement, column: 8)
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
                sql: "SELECT search results",
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
     prepared statement를 준비합니다.

     Parameters:
     - sql: 준비할 SQL 문자열
     - databasePointer: statement를 준비할 SQLite 연결 포인터

     Returns:
     - 준비된 SQLite statement

     Throws:
     - statement 준비에 실패하면 statementPreparationFailed를 던집니다.
     */
    static func prepareStatement(
        sql: String,
        in databasePointer: OpaquePointer
    ) throws -> OpaquePointer {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(databasePointer, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SearchEngineError.statementPreparationFailed(
                sql: sql,
                message: lastErrorMessage(from: databasePointer)
            )
        }

        return statement
    }

    /*
     SQLite statement를 안전하게 정리합니다.

     Parameters:
     - statement: 정리할 SQLite statement 포인터
     */
    static func finalizeStatement(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }

    /*
     최근 SQLite 오류 메시지를 반환합니다.

     Parameters:
     - databasePointer: 오류 메시지를 조회할 SQLite 연결 포인터

     Returns:
     - SQLite 오류 메시지 문자열
     */
    static func lastErrorMessage(from databasePointer: OpaquePointer) -> String {
        guard let cString = sqlite3_errmsg(databasePointer) else {
            return "Unknown SQLite error."
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
