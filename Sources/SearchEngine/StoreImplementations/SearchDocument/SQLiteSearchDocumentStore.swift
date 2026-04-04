//
//  SQLiteSearchDocumentStore.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation
import SQLite3

/*
 SearchDocument를 SQLite 저장소와 FTS projection에 반영하는 Store 구현체입니다.

 이 타입은 공개 문서 모델을 내부 ManagedObject 표현으로 변환한 뒤,
 일반 문서 테이블과 FTS 테이블을 같은 트랜잭션 안에서 함께 갱신합니다.
 이렇게 하면 문서 원본과 검색 projection 사이의 불일치를 줄이고,
 이후 검색과 제안 구현이 같은 저장 기준을 공유할 수 있습니다.
 */
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

    /*
     SQLiteSearchDocumentStore를 생성합니다.

     Parameters:
     - storage: 문서 저장에 사용할 SQLite foundation
     */
    init(storage: SQLiteStorageProtocol) {
        self.storage = storage
    }

    /*
     문서 한 건을 저장합니다.

     Parameters:
     - document: 저장할 문서

     Throws:
     - 문서 검증 실패 또는 SQLite 저장 작업 실패 시 에러를 던집니다.
     */
    func index(_ document: SearchDocument) throws {
        try index([document])
    }

    /*
     문서 여러 건을 순서대로 저장합니다.

     모든 문서를 먼저 검증한 뒤 하나의 트랜잭션 안에서 projection을 반영하여,
     중간 실패가 발생해도 일부 문서만 저장되는 상태를 방지합니다.

     Parameters:
     - documents: 저장할 문서 목록

     Throws:
     - 문서 검증 실패 또는 SQLite 저장 작업 실패 시 에러를 던집니다.
     */
    func index(_ documents: [SearchDocument]) throws {
        if documents.isEmpty {
            return
        }

        try documents.forEach { try $0.validate() }
        let managedObjects = documents.map { SearchDocumentMapper.toManagedObject($0) }

        try storage.transaction { databasePointer in
            for managedObject in managedObjects {
                try Self.upsert(managedObject: managedObject, in: databasePointer)
            }
        }
    }

    /*
     저장된 문서 한 건을 삭제합니다.

     일반 문서 테이블과 FTS projection을 같은 트랜잭션 안에서 제거하여
     검색 대상과 원본 저장 projection 사이 상태를 일치시킵니다.

     Parameters:
     - id: 삭제할 문서 식별자

     Throws:
     - 식별자 검증 실패 또는 SQLite 삭제 작업 실패 시 에러를 던집니다.
     */
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
    /*
     단일 ManagedObject를 문서 테이블과 FTS 테이블에 반영합니다.

     Parameters:
     - managedObject: 반영할 SearchDocument ManagedObject
     - databasePointer: SQL을 실행할 SQLite 연결 포인터

     Throws:
     - statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
     */
    static func upsert(
        managedObject: SearchDocumentMO,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: upsertDocumentSQL,
            in: databasePointer
        ) { statement in
            try bind(managedObject.id, to: statement, index: 1)
            try bind(managedObject.scope, to: statement, index: 2)
            try bind(managedObject.title, to: statement, index: 3)
            try bind(managedObject.body, to: statement, index: 4)
            try bind(managedObject.keywords, to: statement, index: 5)
            try bind(managedObject.lastUpdatedAt, to: statement, index: 6)
        }

        try executeStatement(
            sql: deleteFTSProjectionSQL,
            in: databasePointer
        ) { statement in
            try bind(managedObject.id, to: statement, index: 1)
        }

        try executeStatement(
            sql: insertFTSProjectionSQL,
            in: databasePointer
        ) { statement in
            try bind(managedObject.id, to: statement, index: 1)
            try bind(managedObject.scope, to: statement, index: 2)
            try bind(managedObject.title, to: statement, index: 3)
            try bind(managedObject.body, to: statement, index: 4)
            try bind(managedObject.keywords, to: statement, index: 5)
        }
    }

    /*
     FTS projection에서 문서를 제거합니다.

     Parameters:
     - id: 제거할 문서 식별자
     - databasePointer: SQL을 실행할 SQLite 연결 포인터

     Throws:
     - statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
     */
    static func deleteProjection(
        id: String,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: deleteFTSProjectionSQL,
            in: databasePointer
        ) { statement in
            try bind(id, to: statement, index: 1)
        }
    }

    /*
     일반 문서 테이블에서 문서를 제거합니다.

     Parameters:
     - id: 제거할 문서 식별자
     - databasePointer: SQL을 실행할 SQLite 연결 포인터

     Throws:
     - statement 준비, 바인딩, 실행에 실패하면 에러를 던집니다.
     */
    static func deleteDocument(
        id: String,
        in databasePointer: OpaquePointer
    ) throws {
        try executeStatement(
            sql: deleteDocumentSQL,
            in: databasePointer
        ) { statement in
            try bind(id, to: statement, index: 1)
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
     실수 값을 SQLite parameter에 바인딩합니다.

     Parameters:
     - value: 바인딩할 실수 값
     - statement: 값을 바인딩할 SQLite statement
     - index: parameter 인덱스

     Throws:
     - 바인딩에 실패하면 statementBindingFailed를 던집니다.
     */
    static func bind(
        _ value: Double,
        to statement: OpaquePointer,
        index: Int32
    ) throws {
        let result = sqlite3_bind_double(statement, index, value)

        guard result == SQLITE_OK else {
            throw SearchEngineError.statementBindingFailed(
                index: index,
                message: "Failed to bind double parameter."
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
