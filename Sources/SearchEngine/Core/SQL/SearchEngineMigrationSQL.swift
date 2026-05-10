//
//  SearchEngineMigrationSQL.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/// SearchEngine에서 공통으로 사용하는 SQLite 스키마 SQL 모음입니다.
enum SearchEngineMigrationSQL {
    /// SearchEngine 내부 메타데이터 테이블 이름입니다.
    static let metadataTableName = "search_engine_metadata"

    /// SearchEngine 내부 메타데이터 갱신 시각 인덱스 이름입니다.
    static let metadataUpdatedAtIndexName = "idx_search_engine_metadata_updated_at"

    /// SearchEngine 원본 문서 저장 테이블 이름입니다.
    static let documentsTableName = "search_documents"

    /// SearchEngine 문서 범위/갱신 시각 인덱스 이름입니다.
    static let documentsScopeUpdatedAtIndexName = "idx_search_documents_scope_updated_at"

    /// SearchEngine FTS5 문서 projection 테이블 이름입니다.
    static let documentsFTSTableName = "search_documents_fts"

    /// SearchEngine 내부 메타데이터 테이블 생성 SQL입니다.
    static let createMetadataTable = """
    CREATE TABLE IF NOT EXISTS \(metadataTableName) (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at REAL NOT NULL
    );
    """

    /// 메타데이터 갱신 시각 조회용 인덱스 생성 SQL입니다.
    static let createMetadataUpdatedAtIndex = """
    CREATE INDEX IF NOT EXISTS \(metadataUpdatedAtIndexName)
    ON \(metadataTableName) (updated_at DESC);
    """

    /// 검색 문서 원본 저장 테이블 생성 SQL입니다.
    static let createDocumentsTable = """
    CREATE TABLE IF NOT EXISTS \(documentsTableName) (
        id TEXT PRIMARY KEY,
        scope TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        keywords TEXT NOT NULL,
        last_updated_at REAL NOT NULL
    );
    """

    /// 검색 범위와 최신성 정렬을 위한 인덱스 생성 SQL입니다.
    static let createDocumentsScopeUpdatedAtIndex = """
    CREATE INDEX IF NOT EXISTS \(documentsScopeUpdatedAtIndexName)
    ON \(documentsTableName) (scope, last_updated_at DESC);
    """

    /// FTS5 기반 문서 projection 테이블 생성 SQL입니다.
    static let createDocumentsFTSTable = """
    CREATE VIRTUAL TABLE IF NOT EXISTS \(documentsFTSTableName)
    USING fts5(
        id UNINDEXED,
        scope UNINDEXED,
        title,
        body,
        keywords,
        tokenize = 'unicode61',
        prefix = '2 3 4'
    );
    """
}
