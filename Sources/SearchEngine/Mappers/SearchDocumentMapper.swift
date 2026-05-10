//
//  SearchDocumentMapper.swift
//  SearchEngine
//
//  Created by jch on 4/4/26.
//

import Foundation

/// SearchDocument와 SearchDocumentRecord 사이의 변환을 담당하는 Mapper입니다.
///
/// SearchEngine API는 SearchDocument를 외부 계약으로 사용하고,
/// SQLite 저장 계층은 SearchDocumentRecord를 사용합니다.
/// 이 타입은 두 표현을 변환하여 계층 간 책임을 분리합니다.
enum SearchDocumentMapper {
    /// 저장소 projection에서 사용할 키워드 구분자입니다.
    private static let keywordsSeparator = "\n"

    /// API 모델을 Record 표현으로 변환합니다.
    ///
    /// - Parameter document: 저장 표현으로 변환할 SearchDocument 값입니다.
    ///
    /// - Returns: SQLite 저장 계층에 기록할 SearchDocumentRecord입니다.
    static func toRecord(
        _ document: SearchDocument
    ) -> SearchDocumentRecord {
        let normalizedKeywords = document.keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: keywordsSeparator)

        return SearchDocumentRecord(
            id: document.id.trimmingCharacters(in: .whitespacesAndNewlines),
            scope: document.scope.normalizedValue,
            title: document.title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: document.body.trimmingCharacters(in: .whitespacesAndNewlines),
            keywords: normalizedKeywords,
            lastUpdatedAt: document.lastUpdatedAt.timeIntervalSince1970
        )
    }

    /// Record 표현을 API 모델로 복원합니다.
    ///
    /// - Parameter record: API 모델로 복원할 SearchDocument Record입니다.
    ///
    /// - Returns: SearchEngine 외부에 전달할 SearchDocument 값 객체입니다.
    static func toDocument(
        _ record: SearchDocumentRecord
    ) -> SearchDocument {
        let keywords = record.keywords
            .components(separatedBy: keywordsSeparator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return SearchDocument(
            id: record.id,
            scope: SearchScope(rawValue: record.scope),
            title: record.title,
            body: record.body,
            keywords: keywords,
            lastUpdatedAt: Date(timeIntervalSince1970: record.lastUpdatedAt)
        )
    }
}
