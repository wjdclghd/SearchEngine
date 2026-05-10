//
//  SearchSuggestionMapper.swift
//  SearchEngine
//
//  Created by jch on 4/5/26.
//

import Foundation

/// SearchSuggestionRecord를 공개 SearchSuggestion 모델로 변환하는 Mapper입니다.
///
/// SQLite suggestion 결과는 내부 저장 표현을 사용하지만,
/// 상위 계층은 공백이 정리된 문자열과 선택적 scope를 포함한 공개 모델이 필요합니다.
/// 이 타입은 suggestion 결과를 화면 친화적인 공개 모델로 정규화하여 변환합니다.
enum SearchSuggestionMapper {
    /// 내부 suggestion 표현을 공개 SearchSuggestion 모델로 변환합니다.
    ///
    /// - Parameter record: 공개 모델로 변환할 SearchSuggestion Record입니다.
    ///
    /// - Returns: 화면과 상위 계층에 전달할 SearchSuggestion 값입니다.
    static func toSearchSuggestion(
        _ record: SearchSuggestionRecord
    ) -> SearchSuggestion {
        let normalizedText = record.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedScope: SearchScope?

        if let scope = record.scope?.trimmingCharacters(in: .whitespacesAndNewlines),
           scope.isEmpty == false {
            normalizedScope = SearchScope(rawValue: scope)
        } else {
            normalizedScope = nil
        }
        let normalizedDocumentID = normalizeOptionalText(record.documentID)
        let normalizedMatchedText = normalizeOptionalText(record.matchedText)

        return SearchSuggestion(
            text: normalizedText,
            scope: normalizedScope,
            score: record.score,
            source: record.source,
            kind: record.kind,
            documentID: normalizedDocumentID,
            matchedText: normalizedMatchedText
        )
    }

    private static func normalizeOptionalText(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedText.isEmpty ? nil : normalizedText
    }
}
