//
//  SearchSuggestionMO.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation

/*
 SearchSuggestion을 SQLite suggestion 결과 계층에서 사용하는 내부 ManagedObject 표현입니다.

 이 타입은 suggestion SQL 결과에서 반환한 제목 문자열, 범위 값, 정렬 점수를 함께 담아
 SQLite 쿼리 결과를 Mapper 계층으로 전달하기 위해 사용합니다.
 제안 결과 조립 과정에서 화면 표시 문자열과 내부 정렬 기준을 분리하지 않고
 일관된 값 타입으로 유지할 수 있도록 설계합니다.
 */
struct SearchSuggestionMO: Equatable, Sendable {
    /*
     suggestion 결과에 표시할 제목 문자열입니다.
     */
    let text: String

    /*
     suggestion 결과에 연결된 범위 값입니다.
     */
    let scope: String?

    /*
     suggestion 정렬에 사용할 내부 점수 값입니다.
     */
    let score: Int
}
