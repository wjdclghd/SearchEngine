//
//  SQLiteSearchDocumentStore.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3

/// SearchDocument를 SQLite 저장소와 FTS projection에 반영하는 Store 구현체입니다.
final class SQLiteSearchDocumentStore {
    private let storage: SQLiteStorageProtocol

    private static let upsertDocumentSQL = """
    INSERT INTO \(SearchEngineMigrationSQL.documentsTableName) (
        id,
        scope,
        title,
        body,
        keywords,
        last_updated_at
    ) VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        scope = excluded.scope,
        title = excluded.title,
        body = excluded.body,
        keywords = excluded.keywords,
        last_updated_at = excluded.last_updated_at;
    """

    private static let deleteFTSProjectionSQL = """
    DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName)
    WHERE id = ?;
    """

    private static let insertFTSProjectionSQL = """
    INSERT INTO \(SearchEngineMigrationSQL.documentsFTSTableName) (
        id,
        scope,
        title,
        body,
        keywords
    ) VALUES (?, ?, ?, ?, ?);
    """

    private static let deleteDocumentSQL = """
    DELETE FROM \(SearchEngineMigrationSQL.documentsTableName)
    WHERE id = ?;
    """

    /// SQLiteSearchDocumentStore를 생성합니다.
    ///
    /// - Parameter storage: 문서 저장에 사용할 SQLite 기반입니다.
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /// 문서 한 건을 저장합니다.
    ///
    /// - Parameter document: 저장할 문서입니다.
    ///
    /// - Throws: 문서 검증 실패 또는 SQLite 저장 작업 실패 시 에러를 던집니다.
    func index(_ document: SearchDocument) throws {
        try index([document])
    }

    /// 문서 여러 건을 하나의 트랜잭션 안에서 저장합니다.
    ///
    /// - Parameter documents: 저장할 문서 목록입니다.
    ///
    /// - Throws: 문서 검증 실패 또는 SQLite 저장 작업 실패 시 에러를 던집니다.
    func index(_ documents: [SearchDocument]) throws {
        if documents.isEmpty {
            return
        }

        try documents.forEach { try $0.validate() }
        let records = documents.map { SearchDocumentMapper.toRecord($0) }

        try storage.transaction { databasePointer in
            for record in records {
                try Self.upsert(record: record, in: databasePointer)
            }
        }
    }

    /// 저장된 문서 한 건을 삭제합니다.
    ///
    /// - Parameter id: 삭제할 문서 식별자입니다.
    ///
    /// - Throws: 식별자 검증 실패 또는 SQLite 삭제 작업 실패 시 에러를 던집니다.
    func deleteDocument(id: String) throws {
        let normalizedIdentifier = id.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedIdentifier.isEmpty {
            throw SearchEngineError.invalidDocument(message: "id must not be empty.")
        }

        try storage.transaction { databasePointer in
            try Self.deleteProjection(id: normalizedIdentifier, in: databasePointer)
            try Self.deleteDocument(id: normalizedIdentifier, in: databasePointer)
        }
    }
}

private extension SQLiteSearchDocumentStore {
    /// 단일 Record를 문서 테이블과 FTS 테이블에 반영합니다.
    ///
    /// - Parameter record: 반영할 SearchDocument Record입니다.
    /// - Parameter databasePointer: SQL을 실행할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
    static func upsert(
        record: SearchDocumentRecord,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: upsertDocumentSQL,
            in: databasePointer
        ) { statement in
            try SQLiteDatabase.bind(record.id, to: statement, index: 1)
            try SQLiteDatabase.bind(record.scope, to: statement, index: 2)
            try SQLiteDatabase.bind(record.title, to: statement, index: 3)
            try SQLiteDatabase.bind(record.body, to: statement, index: 4)
            try SQLiteDatabase.bind(record.keywords, to: statement, index: 5)
            try SQLiteDatabase.bind(record.lastUpdatedAt, to: statement, index: 6)
        }

        try executeStatement(
            sql: deleteFTSProjectionSQL,
            in: databasePointer
        ) { statement in
            try SQLiteDatabase.bind(record.id, to: statement, index: 1)
        }

        try executeStatement(
            sql: insertFTSProjectionSQL,
            in: databasePointer
        ) { statement in
            try SQLiteDatabase.bind(record.id, to: statement, index: 1)
            try SQLiteDatabase.bind(record.scope, to: statement, index: 2)
            try SQLiteDatabase.bind(record.title, to: statement, index: 3)
            try SQLiteDatabase.bind(record.body, to: statement, index: 4)
            try SQLiteDatabase.bind(record.keywords, to: statement, index: 5)
        }
    }

    /// FTS projection에서 문서를 제거합니다.
    ///
    /// - Parameter id: 제거할 문서 식별자입니다.
    /// - Parameter databasePointer: SQL을 실행할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
    static func deleteProjection(
        id: String,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: deleteFTSProjectionSQL,
            in: databasePointer
        ) { statement in
            try SQLiteDatabase.bind(id, to: statement, index: 1)
        }
    }

    /// 일반 문서 테이블에서 문서를 제거합니다.
    ///
    /// - Parameter id: 제거할 문서 식별자입니다.
    /// - Parameter databasePointer: SQL을 실행할 SQLite 연결 포인터입니다.
    ///
    /// - Throws: statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
    static func deleteDocument(
        id: String,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: deleteDocumentSQL,
            in: databasePointer
        ) { statement in
            try SQLiteDatabase.bind(id, to: statement, index: 1)
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
