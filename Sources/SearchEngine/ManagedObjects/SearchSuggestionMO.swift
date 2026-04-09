//
//  SearchSuggestionMO.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation

/*
 SearchSuggestion를 SQLite 자동완성 결과 계층에서 사용하는 내부 ManagedObject 표현입니다.

 이 타입은 suggestion SQL 실행 결과를 Mapper 계층으로 전달하기 위한
 최소 단위 값 객체이며, 외부 공개 모델로 변환하기 전에 필요한 값만
 일관된 내부 형식으로 보관할 수 있도록 설계합니다.
 */
struct SearchSuggestionMO: Equatable, Sendable {
    /*
     자동완성 후보로 노출할 정규화된 suggestion 텍스트입니다.
     */
    let text: String

    /*
     자동완성 후보에 연결된 문서 범위 값입니다.
     */
    let scope: String?

    /*
     자동완성 후보 정렬에 사용하는 내부 점수 값입니다.
     */
    let score: Int
}
