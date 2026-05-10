//
//  SearchHit.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// 검색 결과 한 건을 표현하는 공개 모델입니다.
public struct SearchHit: Equatable, Sendable {
    /// 검색에 일치한 문서입니다.
    public let document: SearchDocument

    /// 검색 엔진이 계산한 결과 점수입니다.
    public let score: Double

    /// 검색 결과에 표시할 스니펫 정보입니다.
    public let snippet: SearchSnippet?

    /// SearchHit를 생성합니다.
    ///
    /// - Parameter document: 검색에 일치한 문서입니다.
    /// - Parameter score: 검색 엔진이 계산한 결과 점수입니다.
    /// - Parameter snippet: 검색 결과에 표시할 스니펫 정보입니다.
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
