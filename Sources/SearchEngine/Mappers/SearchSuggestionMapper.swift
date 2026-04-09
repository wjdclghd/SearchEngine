//
//  SearchSuggestionMapper.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation

/*
 SearchSuggestionMO를 공개 SearchSuggestion 모델로 변환하는 Mapper입니다.

 SQLite suggestion 결과는 내부 저장 표현을 사용하지만,
 상위 계층은 공백이 정리된 문자열과 선택적 scope를 포함한 공개 모델이 필요합니다.
 이 타입은 suggestion 결과를 화면 친화적인 공개 모델로 정규화하여 변환합니다.
 */
enum SearchSuggestionMapper {
    /*
     내부 suggestion 표현을 공개 SearchSuggestion 모델로 변환합니다.

     Parameters:
     - managedObject: 공개 모델로 변환할 SearchSuggestion ManagedObject

     Returns:
     - 화면과 상위 계층에 전달할 SearchSuggestion 값
     */
    static func toSearchSuggestion(
        _ managedObject: SearchSuggestionMO
    ) -> SearchSuggestion {
        let normalizedText = managedObject.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedScope: SearchScope?

        if let scope = managedObject.scope?.trimmingCharacters(in: .whitespacesAndNewlines),
           scope.isEmpty == false {
            normalizedScope = SearchScope(rawValue: scope)
        } else {
            normalizedScope = nil
        }

        return SearchSuggestion(
            text: normalizedText,
            scope: normalizedScope,
            score: managedObject.score
        )
    }
}
