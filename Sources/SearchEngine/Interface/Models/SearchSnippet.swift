//
//  SearchSnippet.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// 검색 결과에 함께 노출할 스니펫 정보를 표현하는 공개 모델입니다.
///
/// 제목과 본문 요약 문자열을 보관하는 단순한 구조로 유지하고,
/// 실제 하이라이트 생성 규칙과 토큰 강조 정책은 Querying 계층에서 확장할 수 있도록 둡니다.
public struct SearchSnippet: Equatable, Sendable {
    /// 제목 기반 스니펫 문자열입니다.
    public let title: String?

    /// 본문 기반 스니펫 문자열입니다.
    public let body: String?

    /// SearchSnippet을 생성합니다.
    ///
    /// - Parameter title: 제목 기반 스니펫 문자열입니다.
    /// - Parameter body: 본문 기반 스니펫 문자열입니다.
    public init(
        title: String?,
        body: String?
    ) {
        self.title = title
        self.body = body
    }
}
