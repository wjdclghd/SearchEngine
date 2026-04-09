//
//  SearchDocument.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 검색 엔진이 색인 대상으로 받는 공개 문서 모델입니다.

 상위 계층은 이 타입을 사용해 문서 식별자, 검색 범위, 제목, 본문,
 검색 보조 키워드와 갱신 시각을 검색 엔진에 전달합니다.
 실제 저장 구조와 FTS 테이블 구성 방식은 SearchEngine 내부 구현에 숨기고,
 외부에는 안정적인 값 타입 계약만 노출하기 위해 사용합니다.
 */
public struct SearchDocument: Equatable, Sendable {
    /*
     문서를 고유하게 식별하는 값입니다.
     */
    public let id: String

    /*
     문서가 속하는 검색 범위입니다.
     */
    public let scope: SearchScope

    /*
     검색 결과에 표시할 문서 제목입니다.
     */
    public let title: String

    /*
     색인 대상이 되는 문서 본문입니다.
     */
    public let body: String

    /*
     검색 보조를 위한 부가 키워드 목록입니다.
     */
    public let keywords: [String]

    /*
     문서가 마지막으로 갱신된 시각입니다.
     */
    public let lastUpdatedAt: Date

    /*
     SearchDocument를 생성합니다.

     Parameters:
     - id: 문서를 고유하게 식별하는 값
     - scope: 문서가 속하는 검색 범위
     - title: 검색 결과에 표시할 문서 제목
     - body: 색인 대상이 되는 문서 본문
     - keywords: 검색 보조를 위한 부가 키워드 목록
     - lastUpdatedAt: 문서가 마지막으로 갱신된 시각
     */
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

    /*
     문서 값이 색인 가능한 상태인지 검증합니다.

     문서 식별자와 범위 식별자는 비어 있으면 안 되며,
     제목과 본문이 모두 비어 있는 문서는 검색 엔진에 의미 있는 색인 대상을 제공하지 못하므로
     미리 차단합니다.

     Throws:
     - 문서 값이 올바르지 않으면 SearchEngineError.invalidDocument
     */
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
