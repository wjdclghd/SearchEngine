//
//  SearchProjectionMapperTests.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation
import XCTest
@testable import SearchEngine

/*
 SearchProjectionMapper의 rebuild projection 변환 규칙을 확인하는 테스트입니다.

 Rebuilder는 documents 원본 row를 그대로 FTS projection으로 옮겨야 하므로,
 Mapper가 문서 식별자, scope, 검색 대상 컬럼을 누락 없이 유지하는지 검증합니다.
 */
final class SearchProjectionMapperTests: XCTestCase {
    /*
     SearchDocument ManagedObject가 projection 값으로 그대로 변환되는지 검증합니다.
     */
    func test_toProjection_mapsManagedObjectFields() {
        let managedObject = SearchDocumentMO(
            id: "notice-1",
            scope: "app.notice",
            title: "Swift Search",
            body: "FTS rebuild",
            keywords: "swift\nsearch",
            lastUpdatedAt: 100
        )

        let projection = SearchProjectionMapper.toProjection(managedObject)

        XCTAssertEqual(
            projection,
            SearchProjectionMapper.Projection(
                id: "notice-1",
                scope: "app.notice",
                title: "Swift Search",
                body: "FTS rebuild",
                keywords: "swift\nsearch"
            )
        )
    }
}
