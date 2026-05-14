# SearchEngine Module

Clean Architecture + MVVM 환경에서 App 타겟이 SPM 모듈로 의존하는 형태를 전제로 만든 SearchEngine 모듈입니다.
이 모듈은 **로컬 검색 엔진(Local Search Engine)** 역할에 집중하며, SQLite + FTS5 기반 검색 구조를 외부에 직접 노출하지 않고 **공개 모델 + 공개 계약 + 내부 구현체**로 역할을 분리합니다.

모듈 내부는 문서 색인, 검색, 자동완성, projection rebuild 기능을 포함하며,
상위 계층은 `SearchEngineContainer.makeSearchEngine()`을 통해 `SearchEngineProtocol`을 즉시 사용할 수 있습니다.

**요약**
- 저장소 초기화: `SearchEngineConfiguration` + `SQLiteStorage`
- 조립 진입점: `SearchEngineContainer`
- 공개 엔진: `makeSearchEngine()` → `some SearchEngineProtocol`
- migration 정책: `SearchEngineMigrationPlan`
- 공개 계약: `Interface/Models`, `Interface/Errors`, `Interface/Protocols`
- 내부 구현: `Records`, `Mappers`, `StoreImplementations`, `Support`, `Indexing`
- 구현 기능: `Document Indexing`, `Search`, `Suggestion`, `Rebuild`
- 초성 검색: 자모 전용 입력 감지 + `keywords LIKE` fallback

---

**모듈 구조**
```text
SearchEngine/
├─ Package.swift
├─ Sources/
│  └─ SearchEngine/
│     ├─ Interface/
│     │  ├─ Models/
│     │  │  ├─ SearchDocument.swift
│     │  │  ├─ SearchHit.swift
│     │  │  ├─ SearchQuery.swift
│     │  │  ├─ SearchScope.swift
│     │  │  ├─ SearchSnippet.swift
│     │  │  ├─ SearchSuggestion.swift
│     │  │  └─ SearchSuggestionQuery.swift
│     │  ├─ Errors/
│     │  │  └─ SearchEngineError.swift
│     │  └─ Protocols/
│     │     └─ SearchEngineProtocol.swift
│     ├─ Core/
│     │  ├─ SQLiteDatabase.swift
│     │  ├─ SQLiteDatabaseProtocol.swift
│     │  ├─ SQLiteStorage.swift
│     │  ├─ SQLiteStorageProtocol.swift
│     │  ├─ SQLiteSearchEngine.swift
│     │  ├─ SearchEngineConfiguration.swift
│     │  ├─ SearchEngineContainer.swift
│     │  ├─ SearchEngineMigrationPlan.swift
│     │  └─ SQL/
│     │     └─ SearchEngineMigrationSQL.swift
│     ├─ Records/
│     │  ├─ SearchDocumentRecord.swift
│     │  ├─ SearchHitRecord.swift
│     │  └─ SearchSuggestionRecord.swift
│     ├─ Mappers/
│     │  ├─ SearchDocumentMapper.swift
│     │  ├─ SearchHitMapper.swift
│     │  └─ SearchSuggestionMapper.swift
│     ├─ StoreImplementations/
│     │  ├─ SearchDocument/
│     │  │  └─ SQLiteSearchDocumentStore.swift
│     │  ├─ Search/
│     │  │  └─ SQLiteSearchStore.swift
│     │  └─ SearchSuggestion/
│     │     └─ SQLiteSearchSuggestionStore.swift
│     ├─ Support/
│     │  ├─ SQLBuilder.swift
│     │  └─ SearchMatchQueryBuilder.swift
│     └─ Indexing/
│        ├─ SearchProjectionMapper.swift
│        └─ SearchRebuilder.swift
└─ Tests/
   └─ SearchEngineTests/
      ├─ Core/
      │  ├─ SQLiteDatabaseTests.swift
      │  ├─ SQLiteStorageTests.swift
      │  ├─ SearchEngineConfigurationTests.swift
      │  ├─ SearchEngineMigrationPlanTests.swift
      │  └─ SearchEngineContainerTests.swift
      ├─ Interface/
      │  └─ Models/
      │     ├─ SearchDocumentTests.swift
      │     ├─ SearchQueryTests.swift
      │     ├─ SearchScopeTests.swift
      │     ├─ SearchSuggestionTests.swift
      │     └─ SearchSuggestionQueryTests.swift
      ├─ Mappers/
      │  ├─ SearchDocumentMapperTests.swift
      │  ├─ SearchHitMapperTests.swift
      │  └─ SearchSuggestionMapperTests.swift
      ├─ StoreImplementations/
      │  ├─ SearchDocument/
      │  │  └─ SQLiteSearchDocumentStoreTests.swift
      │  ├─ Search/
      │  │  └─ SQLiteSearchStoreTests.swift
      │  └─ SearchSuggestion/
      │     └─ SQLiteSearchSuggestionStoreTests.swift
      ├─ Support/
      │  ├─ SQLBuilderTests.swift
      │  └─ SearchMatchQueryBuilderTests.swift
      ├─ Indexing/
      │  ├─ SearchProjectionMapperTests.swift
      │  └─ SearchRebuilderTests.swift
      └─ TestSupport/
         ├─ InMemorySQLiteDatabase.swift
         └─ InMemorySQLiteStorage.swift
```

---

**빠른 시작**

`SearchEngineContainer.makeSearchEngine()`은 `SearchEngineProtocol`을 즉시 반환합니다.

```swift
import SearchEngine

let engine = try SearchEngineContainer.makeDefault().makeSearchEngine()

// 문서 색인
try engine.index(SearchDocument(
    id: "guide-1",
    scope: SearchScope(rawValue: "app.guide"),
    title: "Swift Search Engine",
    body: "SQLite FTS5 기반 검색",
    keywords: ["swift", "fts"],
    lastUpdatedAt: Date()
))

// 검색
let hits = try engine.search(SearchQuery(text: "swift"))

// 자동완성
let suggestions = try engine.suggest(SearchSuggestionQuery(text: "swift s"))
```

테스트나 샘플 실행처럼 디스크 저장소가 필요 없는 환경에서는 in-memory 구성을 사용합니다.

```swift
import SearchEngine

let engine = try SearchEngineContainer.makeDefaultInMemory().makeSearchEngine()
```

특정 경로와 SQLite 정책을 직접 제어하려면 설정 객체를 먼저 생성합니다.

```swift
import SearchEngine

let configuration = try SearchEngineConfiguration.live(
    directoryName: "SearchEngine",
    fileName: "SearchEngine.sqlite",
    migrationPlan: .searchIndexing,
    busyTimeoutMilliseconds: 5_000,
    enablesWriteAheadLogging: true,
    enablesForeignKeys: true
)

let engine = try SearchEngineContainer.make(configuration: configuration).makeSearchEngine()
```

---

**핵심 설계 방향**

- **외부 공개 계약과 내부 SQLite 구현 분리**
  상위 계층은 `Interface/Models`, `Interface/Errors`, `Interface/Protocols`에만 의존합니다.
  `sqlite3`, FTS5 SQL, prepared statement, projection 관리 세부 구현은 내부에 감춥니다.

- **조립 지점 통일**
  앱 또는 상위 모듈은 `SearchEngineContainer`를 통해 검색 엔진을 초기화합니다.
  문서 저장, 검색, suggestion, rebuild가 모두 같은 migration 규칙과 같은 SQLite 연결 정책 위에서 동작합니다.

- **기능 책임 분리**
  - 문서 저장: `SQLiteSearchDocumentStore`
  - 검색 실행: `SQLiteSearchStore`
  - 자동완성: `SQLiteSearchSuggestionStore`
  - projection 복구: `SearchRebuilder`
  - SQL 조립 및 FTS 질의: `Support`
  - 값 변환: `Mappers`

- **테스트 친화적인 구조**
  디스크 기반 live 설정과 in-memory SQLite 설정을 모두 지원합니다.
  Core / Interface / Mappers / StoreImplementations / Indexing 단위로 테스트를 분리해 기능 검증 경계를 명확히 유지합니다.

---

**SearchEngineProtocol**

`SearchEngineProtocol`은 상위 계층이 의존하는 공개 검색 엔진 계약입니다.

```swift
public protocol SearchEngineProtocol {
    func index(_ document: SearchDocument) throws
    func index(_ documents: [SearchDocument]) throws
    func deleteDocument(id: String) throws
    func search(_ query: SearchQuery) throws -> [SearchHit]
    func suggest(_ query: SearchSuggestionQuery) throws -> [SearchSuggestion]
    func rebuild() throws
}
```

---

**SearchEngineContainer**

`SearchEngineContainer`는 SearchEngine 모듈의 **조립 진입점(composition entry point)** 입니다.

제공 팩토리:
- `make(configuration:)` — 커스텀 설정 기반 컨테이너
- `makeDefault()` — 디스크 기반 기본 설정 컨테이너
- `makeDefaultInMemory()` — 메모리 기반 컨테이너

제공 메서드:
- `makeSearchEngine() -> some SearchEngineProtocol` — `SQLiteSearchEngine` 반환

```swift
let container = try SearchEngineContainer.makeDefault()
let engine = container.makeSearchEngine()
```

컨테이너가 내부적으로 같은 SQLite foundation을 재사용하는 저장 구현체와 rebuild 구현체를 조립합니다.
`makeSearchEngine()`은 `SQLiteSearchDocumentStore`, `SQLiteSearchStore`, `SQLiteSearchSuggestionStore`, `SearchRebuilder`를 모두 같은 storage 위에 조립해 반환합니다.

---

**SearchEngineConfiguration**

`SearchEngineConfiguration`은 검색 엔진 초기화에 필요한 값을 한 곳에 모아 관리하는 설정 객체입니다.

주요 설정 항목:
- `storage`
- `migrationPlan`
- `busyTimeoutMilliseconds`
- `enablesWriteAheadLogging`
- `enablesForeignKeys`

생성 방법:
- `live(...)`: 디스크 기반 SQLite 저장소
- `inMemory(...)`: 메모리 기반 SQLite 저장소

```swift
// 디스크 기반
let configuration = try SearchEngineConfiguration.live(
    directoryName: "SearchEngine",
    fileName: "SearchEngine.sqlite"
)

// in-memory
let configuration = SearchEngineConfiguration.inMemory(
    identifier: "SearchEngine.InMemory"
)
```

`databaseURL()`을 통해 디스크 저장소일 때 실제 SQLite 파일 경로를 계산할 수 있으며, in-memory 구성에서는 `nil`을 반환합니다.

---

**Migration**

`SearchEngineMigrationPlan`은 SQLite 저장소를 열 때 적용할 migration 정책을 정의합니다.
버전은 SQLite `PRAGMA user_version`으로 추적하며, 현재 버전보다 높은 migration만 적용합니다.

기본 제공 정책:

### sqliteCore
- 메타데이터 테이블 생성 (v1)
- 최소 SQLite foundation 준비

### searchIndexing
- `sqliteCore` 포함
- documents 원본 테이블 생성 (v2)
- scope + updatedAt 인덱스 생성
- FTS5 projection 테이블 생성 (`tokenize = 'unicode61'`, `prefix = '1 2 3 4'`)

### disabled
- migration 미수행
- 이미 준비된 데이터베이스를 외부에서 관리하거나 migration을 별도로 통제하는 환경에서 사용

```swift
let configuration = try SearchEngineConfiguration.live(
    migrationPlan: .searchIndexing
)
```

migration 정책을 결정하는 곳은 `SearchEngineConfiguration`입니다.
`SQLiteStorage`와 `SQLiteDatabase`는 준비된 정책을 기준으로 저장소를 초기화합니다.

---

**현재 구현 기능**

### 1. Document Indexing

문서를 원본 documents 테이블과 FTS projection에 함께 저장합니다.

- `SearchDocument` 검증 수행
- 같은 `id` 기준 upsert 저장
- 문서 삭제 시 원본 row와 projection row를 함께 제거
- 저장/삭제는 transaction 경계 안에서 처리해 정합성 유지
- `scope`, `title`, `body`, `keywords`, `lastUpdatedAt` 정규화 저장
- keywords는 `\n` 구분자로 join해 단일 컬럼에 저장

관련 내부 구현: `SQLiteSearchDocumentStore`, `SearchDocumentRecord`, `SearchDocumentMapper`

### 2. Search

FTS 기반 검색 질의를 실행하고 `SearchHit` 목록을 반환합니다.

- `SearchQuery` 검증 수행
- `scope` 필터 지원
- `limit`, `offset` 지원
- 검색 결과는 `SearchDocument + score + snippet` 형태로 반환
- FTS MATCH 질의와 BM25 기반 정렬 정책 사용

관련 내부 구현: `SQLiteSearchStore`, `SearchHitRecord`, `SearchHitMapper`, `SearchMatchQueryBuilder`

### 3. Suggestion

입력 중인 검색어에 대한 자동완성 결과를 생성합니다.

- `SearchSuggestionQuery` 검증 수행
- title / keywords / body 컬럼 기반 LIKE 매칭
- FTS MATCH와 title LIKE 점수 조합으로 exact / prefix / contains 우선순위 반영
- `scope` 필터 지원
- 같은 title/scope suggestion 중복 제거 (window function `ROW_NUMBER`)
- 중복 문서 수 반영 점수 보정 (`base_score + duplicate_count * 10`)
- 최신 문서와 정규화된 title 기준 정렬 보조 적용

관련 내부 구현: `SQLiteSearchSuggestionStore`, `SearchSuggestionRecord`, `SearchSuggestionMapper`

### 4. 초성 검색 (Korean Consonant Search)

한글 자모(초성) 전용 입력을 감지해 `keywords LIKE` 기반 fallback 경로로 처리합니다.

배경:
- AppData 계층의 `KoreanChosungExtractor`가 한글 제목에서 초성을 추출해 `SearchDocument.keywords`에 추가합니다.
- 예: `"음악"` → 초성 `"ㅇㅇ"`, `"카카오톡"` → `"ㅋㅋㅌ"`
- SearchEngine은 keywords에 저장된 초성을 안정적으로 조회하는 Infrastructure 책임을 담당합니다.

동작 방식:
- `SearchMatchQueryBuilder.isJamoOnlyQuery(_:)`가 입력이 Hangul Compatibility Jamo (U+3130–U+318F)로만 이루어졌는지 판별합니다.
- 자모 전용 입력이면 FTS MATCH 대신 `search_documents` 원본 테이블의 `keywords LIKE '%자모%'` 경로를 사용합니다.
- `unicode61` 토크나이저의 자모 word character 처리 불확실성을 우회해 안정적인 결과를 보장합니다.
- 자모 쿼리 결과는 `source = .keyword`, `kind = .document`로 반환됩니다.
- 같은 title의 중복 제거와 점수 계산은 일반 suggestion과 동일한 CTE 구조를 따릅니다.

완성 음절 입력(예: `"음"`)은 자모 경로가 아닌 기존 FTS prefix MATCH 경로를 사용합니다.

```swift
// "ㅇㅇ" 입력 → keywords에 "ㅇㅇ"가 포함된 문서의 제목을 반환
let suggestions = try engine.suggest(SearchSuggestionQuery(text: "ㅇㅇ"))
// suggestions.first?.text == "음악"
// suggestions.first?.source == .keyword
```

관련 내부 구현: `SearchMatchQueryBuilder.isJamoOnlyQuery(_:)`, `SQLiteSearchSuggestionStore.suggestWithJamoFallback(normalizedInput:query:)`

### 5. Rebuild

원본 documents 테이블을 기준으로 FTS projection 전체를 다시 구성합니다.

- projection 손상 복구 경로 제공
- projection delete + insert를 transaction 경계에서 수행
- 테스트, 장애 복구, migration 이후 정합성 확인에 적합

관련 내부 구현: `SearchRebuilder`, `SearchProjectionMapper`

---

**공개 모델과 계약**

### Models

| 타입 | 설명 |
|---|---|
| `SearchDocument` | 색인 대상 문서. id, scope, title, body, keywords, lastUpdatedAt |
| `SearchHit` | 검색 결과 항목. document, score, snippet |
| `SearchQuery` | 검색 질의. text, scope, limit, offset |
| `SearchScope` | 검색 범위 식별자 |
| `SearchSnippet` | 검색 결과 하이라이트 텍스트 |
| `SearchSuggestion` | 자동완성 후보. text, scope, score, source, kind, documentID, matchedText |
| `SearchSuggestionQuery` | 자동완성 질의. text, scope, limit |

`SearchSuggestionSource`: `.title`, `.body`, `.keyword`
`SearchSuggestionKind`: `.query`, `.document`

### Errors

`SearchEngineError` 주요 케이스:
- `invalidConfiguration`
- `invalidDocument`
- `invalidQuery`
- `databasePathUnavailable`
- `databaseOpenFailed`
- `statementPreparationFailed`
- `statementExecutionFailed`
- `statementBindingFailed`
- `migrationFailed`
- `readFailed`
- `writeFailed`
- `transactionFailed`

### Protocols

`SearchEngineProtocol`: 검색 엔진 공개 계약

상위 계층은 SQLite 내부 타입을 몰라도 됩니다. 공개 계약 기반으로 테스트 더블을 만들거나 내부 구현을 교체할 수 있습니다.

---

**내부 계층 구성**

### Interface
모듈 외부에 공개할 모델, 에러, 프로토콜을 정의합니다.

### Records
SQLite row 결과를 내부에서 다루기 위한 값 타입입니다.
- `SearchDocumentRecord`
- `SearchHitRecord`
- `SearchSuggestionRecord`

### Mappers
공개 모델과 Record 사이를 변환합니다.
- `SearchDocumentMapper`
- `SearchHitMapper`
- `SearchSuggestionMapper`

### StoreImplementations
실제 SQLite 저장/검색/제안 로직을 구현합니다.
- `SQLiteSearchDocumentStore`
- `SQLiteSearchStore`
- `SQLiteSearchSuggestionStore`

### Support
SQL 조립과 FTS 질의 문자열 생성을 보조합니다.
- `SQLBuilder`: ORDER BY, WHERE 절 조립
- `SearchMatchQueryBuilder`: MATCH 쿼리 토큰 정규화, 자모 입력 감지

### Indexing
projection 적재와 rebuild 같은 색인 유지/복구 역할을 담당합니다.
- `SearchProjectionMapper`
- `SearchRebuilder`

---

**SQLite foundation**

Core 계층은 SQLite 기반 foundation을 담당합니다.

- `SQLiteDatabase`: SQLite 연결 열기, PRAGMA 적용, migration 수행, 공통 SQL 실행
- `SQLiteStorage`: read / execute / transaction 경계 관리
- `SearchEngineMigrationSQL`: FTS projection을 포함한 초기 스키마 SQL

FTS5 설정:
```sql
USING fts5(
    id UNINDEXED,
    scope UNINDEXED,
    title,
    body,
    keywords,
    tokenize = 'unicode61',
    prefix = '1 2 3 4'
)
```

`prefix = '1 2 3 4'`는 단일 자모 문자를 포함한 1~4글자 접두어 인덱스를 생성합니다.

---

**테스트**

모듈은 in-memory SQLite 환경을 활용한 129개 테스트를 포함합니다.

포함된 테스트 범위:
- Core foundation: `SQLiteDatabaseTests`, `SQLiteStorageTests`, `SearchEngineConfigurationTests`, `SearchEngineMigrationPlanTests`, `SearchEngineContainerTests`
- Interface Models: `SearchDocumentTests`, `SearchQueryTests`, `SearchScopeTests`, `SearchSuggestionTests`, `SearchSuggestionQueryTests`
- Mappers: `SearchDocumentMapperTests`, `SearchHitMapperTests`, `SearchSuggestionMapperTests`
- StoreImplementations: `SQLiteSearchDocumentStoreTests`, `SQLiteSearchStoreTests`, `SQLiteSearchSuggestionStoreTests`
- Support: `SQLBuilderTests`, `SearchMatchQueryBuilderTests` (자모 감지 포함)
- Indexing: `SearchProjectionMapperTests`, `SearchRebuilderTests`

테스트 전략:
- Core foundation 테스트와 기능 테스트를 분리합니다.
- in-memory SQLite 환경으로 빠르고 독립적인 검증을 수행합니다.
- 자모 입력 시나리오(`"ㅇㅇ"` → `"음악"` 반환 등)를 단위 테스트로 고정합니다.

---

**권장 사용 전략**
- 상위 계층은 `SearchEngineContainer`와 공개 계약 타입을 기준으로 의존성을 설계합니다.
- UseCase/Repository는 `SearchEngineProtocol`과 `Interface/Models` 중심으로 바라봅니다.
- `SQLiteDatabase`, `SQLiteStorage`, `StoreImplementations`, `Indexing` 직접 의존은 SearchEngine 내부에 제한합니다.
- 운영 환경은 `live`, 테스트와 샘플 실행은 `inMemory`를 우선 사용합니다.
- migration 정책은 `SearchEngineMigrationPlan`으로 환경별 분리 구성을 권장합니다.

---

**권장 확장 방식**
1. `Interface/Models`에 공개 모델 추가
2. `Interface/Protocols`에 공개 계약 추가 또는 세분화
3. `Core/SQL`에 migration SQL 추가
4. `SearchEngineMigrationPlan`에 버전 증가 반영
5. `Records`에 내부 row 모델 추가
6. `Mappers`에 변환기 추가
7. `StoreImplementations`에 저장/검색 구현체 추가
8. `Support`에 SQL 조립기 또는 query builder 추가
9. `Indexing`에 projection 유지/복구 로직 추가
10. `SearchEngineContainer`에 공개 조립 경로 또는 엔진 팩토리 추가
11. 기능 전용 테스트 추가

---

Created by: JEONG, Chi-hong  
Updated: May 2026
