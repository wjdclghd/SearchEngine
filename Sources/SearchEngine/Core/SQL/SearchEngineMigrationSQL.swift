//
//  SearchEngineMigrationSQL.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/*
 SearchEngine에서 공통으로 사용하는 SQLite 스키마 SQL 모음입니다.

 migration plan은 버전 순서와 적용 규칙을 담당하고,
 실제 생성할 테이블/인덱스 SQL은 이 파일에서 분리해 관리합니다.
 이렇게 분리해두면 버전이 늘어나더라도 migration plan 파일이 과도하게 비대해지지 않고,
 어떤 버전이 어떤 스키마 조각을 사용하는지 명확하게 추적할 수 있습니다.
 */
enum SearchEngineMigrationSQL {
    /*
     SearchEngine 내부 메타데이터 테이블 이름입니다.
     */
    static let metadataTableName = "search_engine_metadata"

    /*
     SearchEngine 내부 메타데이터 갱신 시각 인덱스 이름입니다.
     */
    static let metadataUpdatedAtIndexName = "idx_search_engine_metadata_updated_at"

    /*
     SearchEngine 원본 문서 저장 테이블 이름입니다.
     */
    static let documentsTableName = "search_documents"

    /*
     SearchEngine 문서 범위/갱신 시각 인덱스 이름입니다.
     */
    static let documentsScopeUpdatedAtIndexName = "idx_search_documents_scope_updated_at"

    /*
     SearchEngine FTS5 문서 projection 테이블 이름입니다.
     */
    static let documentsFTSTableName = "search_documents_fts"

    /*
     SearchEngine 내부 메타데이터 테이블 생성 SQL입니다.

     검색 엔진 공통 메타데이터, 향후 schema 관련 부가 값,
     내부 운영 상태 값을 저장할 수 있는 최소 기반 테이블입니다.
     */
    static let createMetadataTable = """
    CREATE TABLE IF NOT EXISTS \(metadataTableName) (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at REAL NOT NULL
    );
    """

    /*
     메타데이터 갱신 시각 조회용 인덱스 생성 SQL입니다.
     */
    static let createMetadataUpdatedAtIndex = """
    CREATE INDEX IF NOT EXISTS \(metadataUpdatedAtIndexName)
    ON \(metadataTableName) (updated_at DESC);
    """

    /*
     검색 문서 원본 저장 테이블 생성 SQL입니다.

     색인 원본 문서를 안정적으로 보관하고,
     이후 검색 결과 복원과 재색인 동작의 기준 데이터로 사용합니다.
     */
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

    /*
     검색 범위와 최신성 정렬을 위한 인덱스 생성 SQL입니다.
     */
    static let createDocumentsScopeUpdatedAtIndex = """
    CREATE INDEX IF NOT EXISTS \(documentsScopeUpdatedAtIndexName)
    ON \(documentsTableName) (scope, last_updated_at DESC);
    """

    /*
     FTS5 기반 문서 projection 테이블 생성 SQL입니다.

     title, body, keywords를 검색 대상으로 사용하고,
     id와 scope는 원본 문서 복원과 범위 필터링을 위한 보조 컬럼으로 함께 저장합니다.
     */
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
