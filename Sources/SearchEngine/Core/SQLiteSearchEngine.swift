//
//  SQLiteSearchEngine.swift
//  SearchEngine
//
//  Created by jch on 4/30/26.
//

import Foundation

/// SQLite 기반 Store들을 조합해 공개 SearchEngine 계약을 구현합니다.
public final class SQLiteSearchEngine: SearchEngineProtocol {
    private let documentStore: SQLiteSearchDocumentStore
    private let searchStore: SQLiteSearchStore
    private let suggestionStore: SQLiteSearchSuggestionStore
    private let rebuilder: SearchRebuilder

    init(
        documentStore: SQLiteSearchDocumentStore,
        searchStore: SQLiteSearchStore,
        suggestionStore: SQLiteSearchSuggestionStore,
        rebuilder: SearchRebuilder
    ) {
        self.documentStore = documentStore
        self.searchStore = searchStore
        self.suggestionStore = suggestionStore
        self.rebuilder = rebuilder
    }

    /// 문서 한 건을 색인합니다.
    ///
    /// - Parameter document: 색인할 문서입니다.
    ///
    /// - Throws: 문서 검증 또는 SQLite 저장에 실패하면 에러를 던집니다.
    public func index(_ document: SearchDocument) async throws {
        try documentStore.index(document)
    }

    /// 문서 여러 건을 색인합니다.
    ///
    /// - Parameter documents: 색인할 문서 목록입니다.
    ///
    /// - Throws: 문서 검증 또는 SQLite 저장에 실패하면 에러를 던집니다.
    public func index(_ documents: [SearchDocument]) async throws {
        try documentStore.index(documents)
    }

    /// 문서 한 건과 해당 FTS projection을 삭제합니다.
    ///
    /// - Parameter id: 삭제할 문서 식별자입니다.
    ///
    /// - Throws: 문서 식별자 검증 또는 SQLite 삭제에 실패하면 에러를 던집니다.
    public func deleteDocument(id: String) async throws {
        try documentStore.deleteDocument(id: id)
    }

    /// 검색 질의를 실행합니다.
    ///
    /// - Parameter query: 실행할 검색 질의입니다.
    ///
    /// - Returns: 검색 결과 목록입니다.
    ///
    /// - Throws: 질의 검증 또는 SQLite 검색 실행에 실패하면 에러를 던집니다.
    public func search(_ query: SearchQuery) async throws -> [SearchHit] {
        try searchStore.search(query)
    }

    /// 자동완성 후보를 조회합니다.
    ///
    /// - Parameter query: 실행할 자동완성 질의입니다.
    ///
    /// - Returns: 자동완성 후보 목록입니다.
    ///
    /// - Throws: 질의 검증 또는 SQLite suggestion 실행에 실패하면 에러를 던집니다.
    public func suggest(_ query: SearchSuggestionQuery) async throws -> [SearchSuggestion] {
        try suggestionStore.suggest(query)
    }

    /// 저장된 문서 기준으로 FTS projection을 다시 구성합니다.
    ///
    /// - Throws: 원본 문서 조회 또는 FTS projection 재적재에 실패하면 에러를 던집니다.
    public func rebuild() async throws {
        try rebuilder.rebuild()
    }
}
