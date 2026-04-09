//
//  SearchRebuilderTests.swift
//  SearchEngine
//
//  Created by jch on 4/9/26.
//

import Foundation
import SQLite3
import XCTest
@testable import SearchEngine

/*
 SearchRebuilder의 FTS projection 재구성 동작을 확인하는 테스트입니다.

 Rebuilder는 documents 원본 테이블을 기준으로 projection을 전체 교체해야 하므로,
 단순 row 수뿐 아니라 검색 가능 상태 복구, 잘못된 projection 제거, 빈 원본 상태 정리까지 함께 검증합니다.
 */
final class SearchRebuilderTests: XCTestCase {
    /*
     손실된 FTS projection을 documents 원본 테이블 기준으로 복구하는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_rebuild_restoresProjectionFromDocumentsTable() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "notice-1",
                title: "Swift Search",
                body: "Projection restore",
                keywords: ["swift", "search"]
            ),
            makeDocument(
                id: "notice-2",
                title: "SQLite Guide",
                body: "Projection restore",
                keywords: ["sqlite", "guide"]
            )
        ])
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )

        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            0
        )

        try rebuilder.rebuild()

        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage),
            2
        )
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            2
        )
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "swift")).map(\.document.title),
            ["Swift Search"]
        )
    }

    /*
     잘못된 FTS projection이 있어도 rebuild 후 documents 원본 기준으로 교체되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_rebuild_replacesCorruptedProjectionWithDocumentProjection() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index(
            makeDocument(
                id: "notice-1",
                title: "Swift Search",
                body: "Original body",
                keywords: ["swift", "search"]
            )
        )
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )
        try storage.execute(
            sql: """
            INSERT INTO \(SearchEngineMigrationSQL.documentsFTSTableName) (
                id, scope, title, body, keywords
            ) VALUES (
                'notice-1',
                'app.notice',
                'Broken Projection',
                'Broken body',
                'broken'
            );
            """
        )

        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "broken")).map(\.document.title),
            ["Swift Search"]
        )

        try rebuilder.rebuild()

        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "swift")).map(\.document.title),
            ["Swift Search"]
        )
        XCTAssertTrue(
            try searchStore.search(SearchQuery(text: "broken")).isEmpty
        )
    }

    /*
     원본 문서가 없으면 rebuild가 stray projection을 모두 제거하는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_rebuild_withNoDocuments_clearsProjectionTable() throws {
        let storage = try InMemorySQLiteStorage.make()
        let rebuilder = SearchRebuilder(storage: storage)

        try storage.execute(
            sql: """
            INSERT INTO \(SearchEngineMigrationSQL.documentsFTSTableName) (
                id, scope, title, body, keywords
            ) VALUES (
                'orphan-1',
                'app.notice',
                'Orphan Projection',
                'Orphan body',
                'orphan'
            );
            """
        )

        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            1
        )

        try rebuilder.rebuild()

        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsTableName, using: storage),
            0
        )
        XCTAssertEqual(
            try fetchRowCount(in: SearchEngineMigrationSQL.documentsFTSTableName, using: storage),
            0
        )
    }


    /*
     rebuild 이후에도 scope 기반 검색 정합성이 유지되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_rebuild_preservesScopedSearchResult() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index([
            makeDocument(
                id: "guide-1",
                scope: SearchScope(rawValue: "app.guide"),
                title: "Swift Search",
                body: "Guide scope",
                keywords: ["swift", "guide"]
            ),
            makeDocument(
                id: "notice-1",
                scope: SearchScope(rawValue: "app.notice"),
                title: "Swift Intro",
                body: "Notice scope",
                keywords: ["swift", "notice"]
            )
        ])
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )

        try rebuilder.rebuild()

        XCTAssertEqual(
            try searchStore.search(
                SearchQuery(
                    text: "swift",
                    scope: SearchScope(rawValue: "app.guide")
                )
            ).map(\.document.title),
            ["Swift Search"]
        )
    }

    /*
     rebuild 이후에도 title, body, keywords 대상 검색 가능 상태가 유지되는지 검증합니다.

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func test_rebuild_preservesSearchTargetsAcrossTitleBodyAndKeywords() throws {
        let storage = try InMemorySQLiteStorage.make()
        let documentStore = SQLiteSearchDocumentStore(storage: storage)
        let rebuilder = SearchRebuilder(storage: storage)
        let searchStore = SQLiteSearchStore(storage: storage)

        try documentStore.index(
            makeDocument(
                id: "notice-1",
                title: "Swift Search",
                body: "Projection restore body",
                keywords: ["fts", "index"]
            )
        )
        try storage.execute(
            sql: "DELETE FROM \(SearchEngineMigrationSQL.documentsFTSTableName);"
        )

        try rebuilder.rebuild()

        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "swift")).map(\.document.title),
            ["Swift Search"]
        )
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "projection")).map(\.document.title),
            ["Swift Search"]
        )
        XCTAssertEqual(
            try searchStore.search(SearchQuery(text: "fts")).map(\.document.title),
            ["Swift Search"]
        )
    }
}

private extension SearchRebuilderTests {
    /*
     테스트용 SearchDocument를 생성합니다.

     Parameters:
     - id: 문서 식별자
     - scope: 문서 범위
     - title: 문서 제목
     - body: 문서 본문
     - keywords: 문서 키워드 목록
     - lastUpdatedAt: 문서 갱신 시각

     Returns:
     - 테스트에 사용할 SearchDocument
     */
    func makeDocument(
        id: String,
        scope: SearchScope = SearchScope(rawValue: "app.notice"),
        title: String = "Search Engine",
        body: String = "SQLite FTS5 Indexing",
        keywords: [String] = ["swift", "search"],
        lastUpdatedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> SearchDocument {
        SearchDocument(
            id: id,
            scope: scope,
            title: title,
            body: body,
            keywords: keywords,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    /*
     지정한 테이블의 전체 row 수를 조회합니다.

     Parameters:
     - tableName: row 수를 조회할 테이블 이름
     - storage: 조회에 사용할 SQLite 저장 foundation

     Returns:
     - 테이블 전체 row 수

     Throws:
     - 테스트 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRowCount(
        in tableName: String,
        using storage: SQLiteStorageProtocol
    ) throws -> Int {
        try storage.read { databasePointer in
            let statement = try SQLiteDatabase.prepareStatement(
                sql: "SELECT COUNT(*) FROM \(tableName);",
                in: databasePointer
            )
            defer { SQLiteDatabase.finalizeStatement(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }
    }
}
