//
//  SearchHitMapper.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/*
 SearchHitMO를 공개 SearchHit 모델로 변환하는 Mapper입니다.

 SQLite 검색 결과는 문서 원본 컬럼, 점수, 스니펫 문자열을 함께 반환하므로
 외부 API 모델로 전달하기 전에 문서 복원과 스니펫 정규화를 한 번에 수행해야 합니다.
 이 타입은 SearchDocumentMapper를 재사용하여 문서 복원 규칙을 일관되게 유지하고,
 검색 결과 화면 표현에 필요한 SearchHit 구조를 조립합니다.
 */
enum SearchHitMapper {
    /*
     검색 결과 ManagedObject를 공개 SearchHit 모델로 변환합니다.

     Parameters:
     - managedObject: 공개 검색 결과 모델로 변환할 SearchHit ManagedObject

     Returns:
     - SearchEngine 외부에 전달할 SearchHit 값 객체
     */
    static func toSearchHit(
        _ managedObject: SearchHitMO
    ) -> SearchHit {
        let documentManagedObject = SearchDocumentMO(
            id: managedObject.id,
            scope: managedObject.scope,
            title: managedObject.title,
            body: managedObject.body,
            keywords: managedObject.keywords,
            lastUpdatedAt: managedObject.lastUpdatedAt
        )
        let document = SearchDocumentMapper.toDocument(documentManagedObject)
        let titleSnippet = normalizedSnippet(managedObject.titleSnippet)
        let bodySnippet = normalizedSnippet(managedObject.bodySnippet)
        let snippet: SearchSnippet?

        if titleSnippet == nil, bodySnippet == nil {
            snippet = nil
        } else {
            snippet = SearchSnippet(title: titleSnippet, body: bodySnippet)
        }

        return SearchHit(
            document: document,
            score: managedObject.score,
            snippet: snippet
        )
    }
}

private extension SearchHitMapper {
    /*
     스니펫 문자열을 화면 전달 전에 정규화합니다.

     Parameters:
     - value: 정규화할 스니펫 문자열

     Returns:
     - 공백만 있는 경우 nil로 정리된 스니펫 문자열
     */
    static func normalizedSnippet(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
