//
//  SearchSuggestion.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// 자동완성 후보가 어떤 문서 영역에서 생성되었는지 나타냅니다.
public enum SearchSuggestionSource: String, Codable, Equatable, Sendable {
    /// 문서 제목에서 생성된 후보입니다.
    case title

    /// 문서 본문에서 생성된 후보입니다.
    case body

    /// 문서 키워드에서 생성된 후보입니다.
    case keyword
}

/// 자동완성 후보가 어떤 종류의 동작으로 이어지는지 나타냅니다.
public enum SearchSuggestionKind: String, Codable, Equatable, Sendable {
    /// 선택 시 검색어 실행으로 이어지는 후보입니다.
    case query

    /// 선택 시 색인 문서와 연결되는 후보입니다.
    case document
}

/// 자동완성 또는 추천 검색어 한 건을 표현하는 공개 모델입니다.
public struct SearchSuggestion: Equatable, Sendable {
    /// 제안 문자열입니다.
    public let text: String

    /// 제안이 생성된 검색 범위입니다.
    public let scope: SearchScope?

    /// 제안 정렬에 사용할 우선순위 값입니다.
    public let score: Int

    /// 후보가 생성된 문서 영역입니다.
    public let source: SearchSuggestionSource

    /// 후보 선택 시 기대되는 동작 종류입니다.
    public let kind: SearchSuggestionKind

    /// 후보가 특정 색인 문서와 연결될 때 사용하는 식별자입니다.
    public let documentID: String?

    /// 화면에서 강조할 수 있는 입력 문자열입니다.
    public let matchedText: String?

    /// SearchSuggestion을 생성합니다.
    ///
    /// - Parameter text: 제안 문자열입니다.
    /// - Parameter scope: 제안이 생성된 검색 범위입니다.
    /// - Parameter score: 제안 정렬에 사용할 우선순위 값입니다.
    /// - Parameter source: 후보가 생성된 문서 영역입니다.
    /// - Parameter kind: 후보 선택 시 기대되는 동작 종류입니다.
    /// - Parameter documentID: 후보와 연결된 색인 문서 식별자입니다.
    /// - Parameter matchedText: 화면에서 강조할 수 있는 입력 문자열입니다.
    public init(
        text: String,
        scope: SearchScope?,
        score: Int,
        source: SearchSuggestionSource = .title,
        kind: SearchSuggestionKind = .query,
        documentID: String? = nil,
        matchedText: String? = nil
    ) {
        self.text = text
        self.scope = scope
        self.score = score
        self.source = source
        self.kind = kind
        self.documentID = documentID
        self.matchedText = matchedText
    }
}
