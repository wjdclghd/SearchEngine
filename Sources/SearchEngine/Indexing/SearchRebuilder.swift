//
//  SearchRebuilder.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation
import SQLite3

/// documents 원본 테이블을 기준으로 FTS projection을 재구성하는 구현체입니다.
final class SearchRebuilder {
    private let storage: SQLiteStorageProtocol

    private static let selectDocumentsSQL = """
    SELECT id, scope, title, body, keywords, last_updated_at
    FROM \(SearchEngineMigrationSQL.documentsTableName)
    ORDER BY last_updated_at DESC, id ASC;
    """

    private static let deleteAllProjectionSQL = """
    DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);
    """

    private static let insertProjectionSQL = """
    INSERT INTO \(SearchEngineMigrationSQL.documentsFTSTableName) (
        id,
        scope,
        title,
        body,
        keywords
    ) VALUES (?, ?, ?, ?, ?);
    """

    /// SearchRebuilder를 생성합니다.
    ///
    /// - Parameter storage: rebuild 작업에 사용할 SQLite 기반입니다.
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /// documents 원본 테이블 기준으로 FTS projection 전체를 재구성합니다.
    ///
    /// - Throws: 원본 문서 조회 실패 또는 FTS projection 재적재 실패 시 에러를 던집니다.
    func rebuild() throws {
        try storage.transaction { databasePointer in
            let projections = try Self.fetchDocuments(in: databasePointer)
                .map(SearchProjectionMapper.toProjection)

            try Self.deleteAllProjection(in: databasePointer)

            for projection in projections {
                try Self.insertProjection(
                    projection,
                    in: databasePointer
                )
            }
        }
    }
}

private extension SearchRebuilder {
    /// documents 원본 테이블에서 전체 문서를 읽어옵니다.
    ///
    /// - Parameter databasePointer: 조회에 사용할 SQLite 연결 포인터입니다.
    ///
    /// - Returns: 저장된 SearchDocument Record 목록입니다.
    ///
    /// - Throws: statement 준비, 실행 또는 컬럼 복원에 실패하면 에러를 던집니다.
    static func fetchDocuments(
        in databasePointer: OpaquePointer
    ) throws -> [SearchDocumentRecord] {
        let statement = try SQLiteDatabase.prepareStatement(
            sql: selectDocumentsSQL,
            in: databasePointer
        )
        defer { SQLiteDatabase.finalizeStatement(statement) }

        var documents: [SearchDocumentRecord] = []

        while true {
            let stepResult = sqlite3_step(statement)

            if stepResult == SQLITE_DONE {
                break
            }

            guard stepResult == SQLITE_ROW else {
                throw SearchEngineError.statementExecutionFailed(
                    sql: selectDocumentsSQL,
                    message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
                )
            }

            documents.append(
                SearchDocumentRecord(
                    id: try SQLiteDatabase.readRequiredText(from: statement, column: 0, columnName: "id", sql: selectDocumentsSQL),
                    scope: try SQLiteDatabase.readRequiredText(from: statement, column: 1, columnName: "scope", sql: selectDocumentsSQL),
                    title: try SQLiteDatabase.readRequiredText(from: statement, column: 2, columnName: "title", sql: selectDocumentsSQL),
                    body: try SQLiteDatabase.readRequiredText(from: statement, column: 3, columnName: "body", sql: selectDocumentsSQL),
                    keywords: try SQLiteDatabase.readRequiredText(from: statement, column: 4, columnName: "keywords", sql: selectDocumentsSQL),
                    lastUpdatedAt: sqlite3_column_double(statement, 5)
                )
            )
        }

        return documents
    }

    /// 기존 FTS projection 전체를 제거합니다.
    ///
    /// - Parameter databasePointer: SQL을 실행할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: statement 준비, 실행에 실패하면 에러를 던집니다.
    static func deleteAllProjection(
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: deleteAllProjectionSQL,
            in: databasePointer,
            bindings: { _ in }
        )
    }

    /// projection 한 건을 FTS 테이블에 적재합니다.
    ///
    /// - Parameter projection: 적재할 projection 값입니다.
    /// - Parameter databasePointer: SQL을 실행할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
    static func insertProjection(
        _ projection: SearchProjectionMapper.Projection,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: insertProjectionSQL,
            in: databasePointer
        ) { statement in
            try SQLiteDatabase.bind(projection.id, to: statement, index: 1)
            try SQLiteDatabase.bind(projection.scope, to: statement, index: 2)
            try SQLiteDatabase.bind(projection.title, to: statement, index: 3)
            try SQLiteDatabase.bind(projection.body, to: statement, index: 4)
            try SQLiteDatabase.bind(projection.keywords, to: statement, index: 5)
        }
    }

    /// prepared statement 한 건을 공통 방식으로 실행합니다.
    ///
    /// - Parameter sql: 준비하고 실행할 SQL 문자열입니다.
    /// - Parameter databasePointer: SQL을 실행할 SQLite 연결 포인터입니다.
    /// - Parameter bindings: statement에 parameter를 바인딩하는 클로저입니다.
    ///
    /// - Throws: statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
    static func executeStatement(
        sql: String,
        in databasePointer: OpaquePointer,
        bindings: (OpaquePointer) throws -> Void
    ) throws {
        let statement = try SQLiteDatabase.prepareStatement(
            sql: sql,
            in: databasePointer
        )
        defer { SQLiteDatabase.finalizeStatement(statement) }

        try bindings(statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SearchEngineError.statementExecutionFailed(
                sql: sql,
                message: SQLiteDatabase.lastErrorMessage(from: databasePointer)
            )
        }
    }

}
