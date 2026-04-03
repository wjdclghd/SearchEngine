//
//  SearchScope.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 검색 문서가 속하는 논리적 범위를 표현하는 공개 값 타입입니다.

 SearchScope는 문자열 기반 식별자를 감싸는 가벼운 래퍼로,
 상위 계층이 검색 범위를 타입 안전하게 다룰 수 있도록 사용합니다.
 문서 색인 시점과 검색 실행 시점 모두 동일한 범위 식별자를 사용하며,
 저장소 내부에서는 이 값을 정규화된 scope 컬럼에 매핑할 수 있습니다.
 */
public struct SearchScope: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    /*
     검색 범위를 식별하는 원시 문자열 값입니다.
     */
    public let rawValue: String

    /*
     공백을 제거한 정규화 범위 값입니다.

     내부 검증과 SQLite 저장 전처리에서 공통으로 사용할 수 있도록 제공합니다.
     */
    var normalizedValue: String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /*
     검색 범위 식별자가 비어 있는지 여부입니다.
     */
    var isEmpty: Bool {
        normalizedValue.isEmpty
    }

    /*
     원시 문자열 값으로 SearchScope를 생성합니다.

     Parameters:
     - rawValue: 검색 범위를 식별할 문자열 값
     */
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /*
     문자열 리터럴로 SearchScope를 생성합니다.

     Parameters:
     - value: 검색 범위를 식별할 문자열 리터럴
     */
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}
