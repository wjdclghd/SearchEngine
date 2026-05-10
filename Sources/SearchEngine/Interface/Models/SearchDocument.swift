//
//  SearchDocument.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// 검색 엔진이 색인 대상으로 받는 공개 문서 모델입니다.
public struct SearchDocument: Equatable, Sendable {
    /// 문서를 고유하게 식별하는 값입니다.
    public let id: String

    /// 문서가 속하는 검색 범위입니다.
    public let scope: SearchScope

    /// 검색 결과에 표시할 문서 제목입니다.
    public let title: String

    /// 색인 대상이 되는 문서 본문입니다.
    public let body: String

    /// 검색 보조를 위한 부가 키워드 목록입니다.
    public let keywords: [String]

    /// 문서가 마지막으로 갱신된 시각입니다.
    public let lastUpdatedAt: Date

    /// SearchDocument를 생성합니다.
    ///
    /// - Parameter id: 문서를 고유하게 식별하는 값입니다.
    /// - Parameter scope: 문서가 속하는 검색 범위입니다.
    /// - Parameter title: 검색 결과에 표시할 문서 제목입니다.
    /// - Parameter body: 색인 대상이 되는 문서 본문입니다.
    /// - Parameter keywords: 검색 보조를 위한 부가 키워드 목록입니다.
    /// - Parameter lastUpdatedAt: 문서가 마지막으로 갱신된 시각입니다.
    public init(
        id: String,
        scope: SearchScope,
        title: String,
        body: String,
        keywords: [String] = [],
        lastUpdatedAt: Date
    ) {
        self.id = id
        self.scope = scope
        self.title = title
        self.body = body
        self.keywords = keywords
        self.lastUpdatedAt = lastUpdatedAt
    }

    /// 문서 값이 색인 가능한 상태인지 검증합니다.
    ///
    /// - Throws: 문서 값이 올바르지 않으면 SearchEngineError.invalidDocument를 던집니다.
    public func validate() throws {
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SearchEngineError.invalidDocument(message: "id must not be empty.")
        }

        if scope.isEmpty {
            throw SearchEngineError.invalidDocument(message: "scope must not be empty.")
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SearchEngineError.invalidDocument(
                message: "Either title or body must contain searchable content."
            )
        }
    }
}
