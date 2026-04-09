//
//  SearchSuggestion.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 자동완성 또는 추천 검색어 한 건을 표현하는 공개 모델입니다.

 제안 문자열과 해당 제안이 생성된 범위, 우선순위를 함께 보관하여
 상위 계층이 제안 목록을 그대로 화면에 표현할 수 있도록 합니다.
 제안 점수 계산 방식과 정렬 정책은 내부 Suggest 계층에서 담당하고,
 외부에는 단순한 값 타입으로만 노출합니다.
 */
public struct SearchSuggestion: Equatable, Sendable {
    /*
     제안 문자열입니다.
     */
    public let text: String

    /*
     제안이 생성된 검색 범위입니다.
     */
    public let scope: SearchScope?

    /*
     제안 정렬에 사용할 우선순위 값입니다.
     */
    public let score: Int

    /*
     SearchSuggestion을 생성합니다.

     Parameters:
     - text: 제안 문자열
     - scope: 제안이 생성된 검색 범위
     - score: 제안 정렬에 사용할 우선순위 값
     */
    public init(
        text: String,
        scope: SearchScope?,
        score: Int
    ) {
        self.text = text
        self.scope = scope
        self.score = score
    }
}
