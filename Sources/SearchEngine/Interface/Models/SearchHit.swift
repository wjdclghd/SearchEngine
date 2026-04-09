//
//  SearchHit.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 검색 결과 한 건을 표현하는 공개 모델입니다.

 상위 계층은 SearchHit를 사용해 검색된 문서 원본, 랭킹 점수,
 스니펫 정보를 함께 받을 수 있습니다.
 검색 결과 정렬 규칙과 점수 계산 로직은 내부 Querying 계층에서 담당하고,
 외부에는 화면 표현에 필요한 최소 결과 구조만 제공합니다.
 */
public struct SearchHit: Equatable, Sendable {
    /*
     검색에 일치한 문서입니다.
     */
    public let document: SearchDocument

    /*
     검색 엔진이 계산한 결과 점수입니다.
     */
    public let score: Double

    /*
     검색 결과에 표시할 스니펫 정보입니다.
     */
    public let snippet: SearchSnippet?

    /*
     SearchHit를 생성합니다.

     Parameters:
     - document: 검색에 일치한 문서
     - score: 검색 엔진이 계산한 결과 점수
     - snippet: 검색 결과에 표시할 스니펫 정보
     */
    public init(
        document: SearchDocument,
        score: Double,
        snippet: SearchSnippet?
    ) {
        self.document = document
        self.score = score
        self.snippet = snippet
    }
}
