//
//  SearchQuery.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// 검색 실행 시 상위 계층이 전달하는 공개 질의 모델입니다.
public struct SearchQuery: Equatable, Sendable {
    /// 사용자가 입력한 검색 문자열입니다.
    public let text: String

    /// 검색 범위를 제한할 값입니다.
    ///
    /// nil이면 전체 범위를 대상으로 검색합니다.
    public let scope: SearchScope?

    /// 반환할 최대 결과 개수입니다.
    public let limit: Int

    /// 결과 시작 위치입니다.
    public let offset: Int

    /// SearchQuery를 생성합니다.
    ///
    /// - Parameter text: 사용자가 입력한 검색 문자열입니다.
    /// - Parameter scope: 검색 범위 제한 값입니다.
    /// - Parameter limit: 반환할 최대 결과 개수입니다.
    /// - Parameter offset: 결과 시작 위치입니다.
    public init(
        text: String,
        scope: SearchScope? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) {
        self.text = text
        self.scope = scope
        self.limit = limit
        self.offset = offset
    }

    /// 검색 질의 값이 실행 가능한 상태인지 검증합니다.
    ///
    /// - Throws: 질의 값이 올바르지 않으면 SearchEngineError.invalidQuery를 던집니다.
    public func validate() throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SearchEngineError.invalidQuery(message: "text must not be empty.")
        }

        if limit <= 0 {
            throw SearchEngineError.invalidQuery(message: "limit must be greater than zero.")
        }

        if offset < 0 {
            throw SearchEngineError.invalidQuery(message: "offset must be greater than or equal to zero.")
        }

        if scope?.isEmpty == true {
            throw SearchEngineError.invalidQuery(message: "scope must not be empty.")
        }
    }
}
