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
}
