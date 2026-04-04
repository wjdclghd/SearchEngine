//
//  SearchHitMO.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/*
 SearchHit를 SQLite 검색 결과 계층에서 사용하는 내부 ManagedObject 표현입니다.

 이 타입은 문서 원본 컬럼, 검색 점수, 스니펫 컬럼을 한 번에 담아
 SQLite 쿼리 결과를 Mapper 계층으로 전달하기 위해 사용합니다.
 검색 결과 조립 과정에서 원본 문서와 부가 검색 정보를 분리하지 않고
 일관된 값 타입으로 유지할 수 있도록 설계합니다.
 */
struct SearchHitMO: Equatable, Sendable {
    /*
     검색에 일치한 문서 식별자입니다.
     */
    let id: String

    /*
     검색에 일치한 문서 범위 값입니다.
     */
    let scope: String

    /*
     검색 결과에 포함할 문서 제목입니다.
     */
    let title: String

    /*
     검색 결과에 포함할 문서 본문입니다.
     */
    let body: String

    /*
     검색 결과에 포함할 직렬화된 키워드 문자열입니다.
     */
    let keywords: String

    /*
     검색 결과에 포함할 문서 갱신 시각입니다.
     */
    let lastUpdatedAt: TimeInterval

    /*
     SQLite FTS가 계산한 검색 점수입니다.
     */
    let score: Double

    /*
     제목 기반 스니펫 문자열입니다.
     */
    let titleSnippet: String?

    /*
     본문 기반 스니펫 문자열입니다.
     */
    let bodySnippet: String?
}
