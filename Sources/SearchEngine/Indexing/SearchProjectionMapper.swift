//
//  SearchProjectionMapper.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation

/*
 SearchDocument 저장 표현을 FTS projection 재구성 표현으로 변환하는 Mapper입니다.

 SearchRebuilder는 documents 원본 테이블을 기준으로 FTS projection을 다시 채워야 하므로,
 원본 저장용 ManagedObject에서 projection에 필요한 값만 분리해 사용할 수 있어야 합니다.
 이 타입은 rebuild 과정에서 사용할 projection 전용 값 타입을 만들어
 재색인 규칙을 한 곳에 모으고 SearchDocument 저장 규칙과 같은 기준을 유지하도록 돕습니다.
 */
enum SearchProjectionMapper {
    /*
     FTS projection 재구성에 사용할 내부 값 표현입니다.

     documents 원본 row에서 projection에 필요한 컬럼만 보관하며,
     SearchRebuilder는 이 값을 그대로 FTS 테이블에 기록합니다.
     */
    struct Projection: Equatable, Sendable {
        /*
         projection과 원본 문서를 연결할 식별자입니다.
         */
        let id: String

        /*
         projection 범위 필터링에 사용할 정규화된 scope 값입니다.
         */
        let scope: String

        /*
         title 검색에 사용할 projection 제목 문자열입니다.
         */
        let title: String

        /*
         body 검색에 사용할 projection 본문 문자열입니다.
         */
        let body: String

        /*
         keywords 검색에 사용할 직렬화된 키워드 문자열입니다.
         */
        let keywords: String
    }

    /*
     SearchDocument 저장 표현을 projection 재구성 표현으로 변환합니다.

     Parameters:
     - managedObject: projection 값으로 변환할 SearchDocumentMO

     Returns:
     - FTS 재구성에 사용할 Projection 값
     */
    static func toProjection(
        _ managedObject: SearchDocumentMO
    ) -> Projection {
        Projection(
            id: managedObject.id,
            scope: managedObject.scope,
            title: managedObject.title,
            body: managedObject.body,
            keywords: managedObject.keywords
        )
    }
}
