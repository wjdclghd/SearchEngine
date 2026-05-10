//
//  SQLiteSearchStore.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3

/// SearchQuery를 SQLite FTS5 질의로 실행하는 Store 구현체입니다.
final class SQLiteSearchStore {
    private let storage: SQLiteStorageProtocol

    private static let titleSnippetStartMarker = "<b>"
    private static let titleSnippetEndMarker = "</b>"
    private static let bodySnippetStartMarker = "<b>"
    private static let bodySnippetEndMarker = "</b>"
    private static let snippetEllipsis = "…"

    /// SQLiteSearchStore를 생성합니다.
    ///
    /// - Parameter storage: 검색 실행에 사용할 SQLite 기반입니다.
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /// SearchQuery를 실행해 검색 결과 목록을 반환합니다.
    ///
    /// - Parameter query: 실행할 검색 질의입니다.
    ///
    /// - Returns: 검색 결과 목록입니다.
    ///
    /// - Throws: 질의 검증 실패 또는 SQLite 검색 실행 실패 시 에러를 던집니다.
    func search(_ query: SearchQuery) throws -> [SearchHit] {
        try query.validate()

        let matchQuery = try SearchMatchQueryBuilder.buildMatchQuery(from: query)
        let sql = Self.searchSQL(hasScopeFilter: query.scope != nil)

        return try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(sql: sql, in: databasePointer)
            defer { SQLiteDatabase.finalizeStatement(statement) }

            var bindingIndex: Int32 = 1
            try SQLiteDatabase.bind(matchQuery, to: statement, index: bindingIndex)
            bindingIndex += 1

            if let scope = query.scope {
                try SQLiteDatabase.bind(scope.normalizedValue, to: statement, index: bindingIndex)
                bindingIndex += 1
            }

            try SQLiteDatabase.bind(query.limit, to: statement, index: bindingIndex)
            bindingIndex += 1
            try SQLiteDatabase.bind(query.offset, to: statement, index: bindingIndex)

            var hits: [SearchHit] = []

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

                let record = try Self.makeSearchHitRecord(from: statement)
                hits.append(SearchHitMapper.toSearchHit(record))
            }

            return hits
        }
    }
}

private extension SQLiteSearchStore {
    /// 범위 필터 포함 여부에 따라 검색 SQL을 생성합니다.
    ///
    /// - Parameter hasScopeFilter: 범위 필터 적용 여부입니다.
    ///
    /// - Returns: 실행할 검색 SQL 문자열입니다.
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

    /// SQLite 검색 결과 한 행을 SearchHit Record로 복원합니다.
    ///
    /// - Parameter statement: 현재 행을 가리키는 SQLite statement입니다.
    ///
    /// - Returns: Mapper 계층으로 전달할 SearchHit Record입니다.
    ///
    /// - Throws: 필수 컬럼을 문자열로 읽지 못하면 에러를 던집니다.
    static func makeSearchHitRecord(
        from statement: OpaquePointer
    ) throws -> SearchHitRecord {
        SearchHitRecord(
            id: try SQLiteDatabase.readRequiredText(from: statement, column: 0, columnName: "id", sql: "SELECT search results"),
            scope: try SQLiteDatabase.readRequiredText(from: statement, column: 1, columnName: "scope", sql: "SELECT search results"),
            title: try SQLiteDatabase.readRequiredText(from: statement, column: 2, columnName: "title", sql: "SELECT search results"),
            body: try SQLiteDatabase.readRequiredText(from: statement, column: 3, columnName: "body", sql: "SELECT search results"),
            keywords: try SQLiteDatabase.readRequiredText(from: statement, column: 4, columnName: "keywords", sql: "SELECT search results"),
            lastUpdatedAt: sqlite3_column_double(statement, 5),
            score: sqlite3_column_double(statement, 6),
            titleSnippet: SQLiteDatabase.readOptionalText(from: statement, column: 7),
            bodySnippet: SQLiteDatabase.readOptionalText(from: statement, column: 8)
        )
    }

}
