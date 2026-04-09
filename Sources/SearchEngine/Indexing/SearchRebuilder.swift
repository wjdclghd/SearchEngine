//
//  SearchRebuilder.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation
import SQLite3

/*
 documents 원본 테이블을 기준으로 FTS projection을 다시 구성하는 rebuild 구현체입니다.

 SearchDocumentStore는 일반 저장 시점마다 projection을 함께 갱신하지만,
 테스트나 장애 복구 상황에서는 이미 저장된 원본 문서를 기준으로 FTS projection만 다시 채워야 할 수 있습니다.
 이 타입은 documents 테이블을 기준 데이터로 읽어 projection 전체를 비우고 다시 적재하여,
 원본 문서와 검색 projection 사이 정합성을 복구하는 역할을 담당합니다.
 */
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

    /*
     SearchRebuilder를 생성합니다.

     Parameters:
     - storage: rebuild 작업에 사용할 SQLite foundation
     */
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /*
     documents 원본 테이블 기준으로 FTS projection 전체를 재구성합니다.

     원본 문서 조회와 projection 교체를 같은 트랜잭션 안에서 수행하여,
     rebuild 도중 실패하면 이전 projection 상태가 그대로 유지되도록 합니다.
     이를 통해 rebuild 시작 시점의 documents 스냅샷과 projection 결과 사이 정합성을 함께 보장합니다.

     Throws:
     - 원본 문서 조회 실패 또는 FTS projection 재적재 실패 시 에러를 던집니다.
     */
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
    /*
     documents 원본 테이블에서 전체 문서를 읽어옵니다.

     Parameters:
     - databasePointer: 조회에 사용할 SQLite 연결 포인터

     Returns:
     - 저장된 SearchDocument ManagedObject 목록

     Throws:
     - statement 준비, 실행 또는 컬럼 복원에 실패하면 에러를 던집니다.
     */
    static func fetchDocuments(
        in databasePointer: OpaquePointer
    ) throws -> [SearchDocumentMO] {
        let statement = try SQLiteDatabase.prepareStatement(
            sql: selectDocumentsSQL,
            in: databasePointer
        )
        defer { SQLiteDatabase.finalizeStatement(statement) }

        var documents: [SearchDocumentMO] = []

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
                SearchDocumentMO(
                    id: try readRequiredText(from: statement, column: 0, columnName: "id"),
                    scope: try readRequiredText(from: statement, column: 1, columnName: "scope"),
                    title: try readRequiredText(from: statement, column: 2, columnName: "title"),
                    body: try readRequiredText(from: statement, column: 3, columnName: "body"),
                    keywords: try readRequiredText(from: statement, column: 4, columnName: "keywords"),
                    lastUpdatedAt: sqlite3_column_double(statement, 5)
                )
            )
        }

        return documents
    }

    /*
     기존 FTS projection 전체를 제거합니다.

     Parameters:
     - databasePointer: SQL을 실행할 SQLite 연결 포인터

     Throws:
     - statement 준비, 실행에 실패하면 에러를 던집니다.
     */
    static func deleteAllProjection(
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: deleteAllProjectionSQL,
            in: databasePointer,
            bindings: { _ in }
        )
    }

    /*
     projection 한 건을 FTS 테이블에 적재합니다.

     Parameters:
     - projection: 적재할 projection 값
     - databasePointer: SQL을 실행할 SQLite 연결 포인터

     Throws:
     - statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
     */
    static func insertProjection(
        _ projection: SearchProjectionMapper.Projection,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: insertProjectionSQL,
            in: databasePointer
        ) { statement in
            try bind(projection.id, to: statement, index: 1)
            try bind(projection.scope, to: statement, index: 2)
            try bind(projection.title, to: statement, index: 3)
            try bind(projection.body, to: statement, index: 4)
            try bind(projection.keywords, to: statement, index: 5)
        }
    }

    /*
     prepared statement 한 건을 공통 방식으로 실행합니다.

     Parameters:
     - sql: 준비하고 실행할 SQL 문자열
     - databasePointer: SQL을 실행할 SQLite 연결 포인터
     - bindings: statement에 parameter를 바인딩하는 클로저

     Throws:
     - statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
     */
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
                sql: selectDocumentsSQL,
                message: "Missing required text column: \(columnName)."
            )
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
     SQLite 문자열 바인딩에서 사용할 transient destructor입니다.
     */
    static var sqliteTransientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
