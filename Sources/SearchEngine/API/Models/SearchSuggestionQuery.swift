//
//  SearchSuggestionQuery.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 검색 제안 요청 시 사용하는 공개 질의 모델입니다.

 사용자가 입력 중인 문자열, 검색 범위, 반환 개수를 함께 전달하여
 제안 생성기와 상위 계층 사이의 계약을 단순하게 유지합니다.
 자동완성, 추천 검색어, prefix 검색 같은 다양한 제안 전략은
 이후 Suggest 계층에서 이 값을 기준으로 확장할 수 있습니다.
 */
public struct SearchSuggestionQuery: Equatable, Sendable {
    /*
     사용자가 입력 중인 문자열입니다.
     */
    public let text: String

    /*
     제안 범위를 제한할 값입니다.

     nil이면 전체 범위를 대상으로 제안을 생성합니다.
     */
    public let scope: SearchScope?

    /*
     반환할 최대 제안 개수입니다.
     */
    public let limit: Int

    /*
     SearchSuggestionQuery를 생성합니다.

     Parameters:
     - text: 사용자가 입력 중인 문자열
     - scope: 제안 범위 제한 값
     - limit: 반환할 최대 제안 개수
     */
    public init(
        text: String,
        scope: SearchScope? = nil,
        limit: Int = 10
    ) {
        self.text = text
        self.scope = scope
        self.limit = limit
    }

    /*
     검색 제안 질의 값이 실행 가능한 상태인지 검증합니다.

     빈 제안 문자열, 0 이하의 limit, 빈 검색 범위는
     실제 Suggest 계층에서 모호한 분기를 만들 수 있으므로
     foundation 단계에서 먼저 차단합니다.

     Throws:
     - 질의 값이 올바르지 않으면 SearchEngineError.invalidQuery
     */
    public func validate() throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SearchEngineError.invalidQuery(message: "text must not be empty.")
        }

        if limit <= 0 {
            throw SearchEngineError.invalidQuery(message: "limit must be greater than zero.")
        }

        if scope?.isEmpty == true {
            throw SearchEngineError.invalidQuery(message: "scope must not be empty.")
        }
    }
}
