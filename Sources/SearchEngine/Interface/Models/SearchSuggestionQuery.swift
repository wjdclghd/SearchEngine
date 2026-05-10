//
//  SearchSuggestionQuery.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// 검색 자동완성 요청 시 사용하는 공개 질의 모델입니다.
///
/// 사용자가 입력 중인 문자열, 검색 범위, 반환 개수를 함께 전달하여
/// 자동완성 생성기와 상위 계층 사이의 계약을 단순하게 유지합니다.
/// 현재 자동완성은 title, keywords, body 기반 후보를 조회하고,
/// source 구분과 exact/prefix/contains 우선순위 조정은 내부 Suggest 계층에서 담당합니다.
public struct SearchSuggestionQuery: Equatable, Sendable {
    /// 허용하는 최대 자동완성 개수입니다.
    public static let maximumLimit = 50

    /// 사용자가 입력 중인 문자열입니다.
    public let text: String

    /// 자동완성 범위를 제한할 값입니다.
    ///
    /// nil이면 전체 범위를 대상으로 자동완성을 생성합니다.
    public let scope: SearchScope?

    /// 반환할 최대 자동완성 개수입니다.
    public let limit: Int

    /// SearchSuggestionQuery를 생성합니다.
    ///
    /// - Parameter text: 사용자가 입력 중인 문자열입니다.
    /// - Parameter scope: 자동완성 범위 제한 값입니다.
    /// - Parameter limit: 반환할 최대 자동완성 개수입니다.
    public init(
        text: String,
        scope: SearchScope? = nil,
        limit: Int = 10
    ) {
        self.text = text
        self.scope = scope
        self.limit = limit
    }

    /// 검색 자동완성 질의 값이 실행 가능한 상태인지 검증합니다.
    ///
    /// 빈 입력 문자열, 0 이하의 limit, 상한을 초과한 limit, 빈 검색 범위는
    /// 실제 Suggest 계층에서 모호한 분기와 과도한 조회 비용을 만들 수 있으므로
    /// 먼저 차단합니다.
    ///
    /// - Throws: 질의 값이 올바르지 않으면 SearchEngineError.invalidQuery를 던집니다.
    public func validate() throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SearchEngineError.invalidQuery(message: "text must not be empty.")
        }

        if limit <= 0 {
            throw SearchEngineError.invalidQuery(message: "limit must be greater than zero.")
        }

        if limit > Self.maximumLimit {
            throw SearchEngineError.invalidQuery(
                message: "limit must be less than or equal to \(Self.maximumLimit)."
            )
        }

        if scope?.isEmpty == true {
            throw SearchEngineError.invalidQuery(message: "scope must not be empty.")
        }
    }
}
