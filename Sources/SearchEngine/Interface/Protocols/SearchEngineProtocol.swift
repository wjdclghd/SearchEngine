//
//  SearchEngineProtocol.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/*
 SearchEngine 모듈이 외부에 노출하는 최상위 검색 엔진 계약입니다.

 상위 계층은 이 프로토콜에 의존하여 문서 색인, 검색, 자동완성,
 재색인 기능을 호출할 수 있습니다.
 실제 SQLite/FTS5 기반 구현 상세는 내부 구현체에 숨기고,
 모듈 외부에는 기능 중심 계약만 노출하기 위해 사용합니다.
 */
public protocol SearchEngineProtocol {
    /*
     문서 한 건을 색인합니다.

     Parameters:
     - document: 색인할 문서

     Throws:
     - 색인 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func index(_ document: SearchDocument) async throws

    /*
     문서 여러 건을 색인합니다.

     Parameters:
     - documents: 색인할 문서 목록

     Throws:
     - 색인 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func index(_ documents: [SearchDocument]) async throws

    /*
     문서 한 건을 삭제합니다.

     Parameters:
     - id: 삭제할 문서 식별자

     Throws:
     - 삭제 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func deleteDocument(id: String) async throws

    /*
     검색 질의를 실행합니다.

     Parameters:
     - query: 검색 질의 값

     Returns:
     - 검색 결과 목록

     Throws:
     - 검색 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func search(_ query: SearchQuery) async throws -> [SearchHit]

    /*
     검색 제안을 조회합니다.

     Parameters:
     - query: 제안 질의 값

     Returns:
     - 자동완성 또는 추천 검색어 목록

     Throws:
     - 제안 생성 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func suggest(_ query: SearchSuggestionQuery) async throws -> [SearchSuggestion]

    /*
     전체 색인을 재구성합니다.

     Throws:
     - 재색인 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func rebuild() async throws
}
