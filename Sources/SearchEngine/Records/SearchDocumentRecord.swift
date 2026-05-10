//
//  SearchDocumentRecord.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/// SearchDocument를 SQLite 저장 계층에서 사용하는 내부 Record 표현입니다.
///
/// 이 타입은 Core Data 객체가 아니라 SQLite 테이블과 FTS projection에 맞춘 값 타입입니다.
/// StoreImplementations 계층은 이 타입을 사용해 저장 규칙을 일관되게 유지하고,
/// Mappers 계층은 이 타입과 SearchDocument 사이를 변환합니다.
struct SearchDocumentRecord: Equatable, Sendable {
    /// 문서를 고유하게 식별하는 저장소 키입니다.
    let id: String

    /// 정규화된 검색 범위 값입니다.
    let scope: String

    /// 검색 결과에 표시할 저장용 제목 문자열입니다.
    let title: String

    /// FTS 색인 대상이 되는 저장용 본문 문자열입니다.
    let body: String

    /// 줄바꿈 구분자로 직렬화한 저장용 키워드 문자열입니다.
    let keywords: String

    /// 정렬과 최신성 판단에 사용할 저장용 갱신 시각 값입니다.
    let lastUpdatedAt: TimeInterval
}
