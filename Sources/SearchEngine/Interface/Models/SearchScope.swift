//
//  SearchScope.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// 검색 문서가 속하는 논리적 범위를 표현하는 공개 값 타입입니다.
public struct SearchScope: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    /// 검색 범위를 식별하는 원시 문자열 값입니다.
    public let rawValue: String

    /// 공백을 제거한 정규화 범위 값입니다.
    var normalizedValue: String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 검색 범위 식별자가 비어 있는지 여부입니다.
    var isEmpty: Bool {
        normalizedValue.isEmpty
    }

    /// 원시 문자열 값으로 SearchScope를 생성합니다.
    ///
    /// - Parameter rawValue: 검색 범위를 식별할 문자열 값입니다.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// 문자열 리터럴로 SearchScope를 생성합니다.
    ///
    /// - Parameter value: 검색 범위를 식별할 문자열 리터럴입니다.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}
