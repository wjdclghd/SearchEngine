//
//  SearchDocumentMapper.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/*
 SearchDocument와 SearchDocumentMO 사이의 변환을 담당하는 Mapper입니다.

 SearchEngine API는 SearchDocument를 외부 계약으로 사용하고,
 SQLite 저장 계층은 SearchDocumentMO를 사용합니다.
 이 타입은 두 표현을 변환하여 계층 간 책임을 분리합니다.
 */
enum SearchDocumentMapper {
    /*
     저장소 projection에서 사용할 키워드 구분자입니다.
     */
    private static let keywordsSeparator = "\n"

    /*
     API 모델을 ManagedObject 표현으로 변환합니다.

     Parameters:
     - document: 저장 표현으로 변환할 SearchDocument 값

     Returns:
     - SQLite 저장 계층에 기록할 SearchDocumentMO
     */
    static func toManagedObject(
        _ document: SearchDocument
    ) -> SearchDocumentMO {
        let normalizedKeywords = document.keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: keywordsSeparator)

        return SearchDocumentMO(
            id: document.id.trimmingCharacters(in: .whitespacesAndNewlines),
            scope: document.scope.normalizedValue,
            title: document.title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: document.body.trimmingCharacters(in: .whitespacesAndNewlines),
            keywords: normalizedKeywords,
            lastUpdatedAt: document.lastUpdatedAt.timeIntervalSince1970
        )
    }

    /*
     ManagedObject 표현을 API 모델로 복원합니다.

     Parameters:
     - managedObject: API 모델로 복원할 SearchDocument ManagedObject

     Returns:
     - SearchEngine 외부에 전달할 SearchDocument 값 객체
     */
    static func toDocument(
        _ managedObject: SearchDocumentMO
    ) -> SearchDocument {
        let keywords = managedObject.keywords
            .components(separatedBy: keywordsSeparator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return SearchDocument(
            id: managedObject.id,
            scope: SearchScope(rawValue: managedObject.scope),
            title: managedObject.title,
            body: managedObject.body,
            keywords: keywords,
            lastUpdatedAt: Date(timeIntervalSince1970: managedObject.lastUpdatedAt)
        )
    }
}
