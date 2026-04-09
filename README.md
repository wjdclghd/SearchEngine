# SearchEngine Module

Clean Architecture + MVVM 환경에서 App 타겟이 SPM 모듈로 의존하는 형태를 전제로 만든 SearchEngine 모듈입니다.
이 모듈은 **로컬 검색 엔진(Local Search Engine)** 역할에 집중하며, SQLite + FTS5 기반 검색 구조를 외부에 직접 노출하지 않고 **공개 모델 + 공개 계약 + 내부 구현체**로 역할을 분리합니다.

모듈 내부는 문서 색인, 검색, 자동완성, projection rebuild 기능을 단계적으로 확장할 수 있도록 설계되어 있으며,
상위 계층은 `SearchEngineContainer`를 통해 검색 엔진 foundation을 초기화하고 필요한 공개 계약에 의존하도록 구성합니다.

현재 업로드된 구현 기준으로는 **SQLite foundation과 공개 계약, 내부 Store/Indexing 구현체, rebuild 경로, 테스트 기반 검증 구조**까지 포함되어 있습니다.
다만 아직 **모듈 외부에서 바로 사용할 공개 SearchEngine 구현체는 노출하지 않고**, `SearchEngineProtocol`과 `SearchEngineContainer` 중심으로 초기화 기반을 먼저 마련한 상태입니다.

**요약**
- 저장소 초기화: `SearchEngineConfiguration` + `SQLiteStorage`
- 조립 진입점: `SearchEngineContainer`
- migration 정책: `SearchEngineMigrationPlan`
- 공개 계약: `Interface/Models`, `Interface/Errors`, `Interface/Protocols`
- 내부 구현: `ManagedObjects`, `Mappers`, `StoreImplementations`, `Support`, `Indexing`
- 현재 구현 기능: `Document Indexing`, `Search`, `Suggestion`, `Rebuild`
- 현재 공개 상태: foundation/계약 공개, 내부 Store/Indexing 구현체는 모듈 내부 조립 기준

---

**모듈 구조**
- Interface
  - Models
  - Errors
  - Protocols
- Core
- ManagedObjects
- Mappers
- StoreImplementations
- Support
- Indexing
- Tests

예시 구조:
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
│     │  ├─ SearchEngineConfiguration.swift
│     │  ├─ SearchEngineContainer.swift
│     │  ├─ SearchEngineMigrationPlan.swift
│     │  └─ SQL/
│     │     └─ SearchEngineMigrationSQL.swift
│     ├─ ManagedObjects/
│     │  ├─ SearchDocumentMO.swift
│     │  ├─ SearchHitMO.swift
│     │  └─ SearchSuggestionMO.swift
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
      └─ TestSupportTests/
         ├─ InMemorySQLiteDatabase.swift
         └─ InMemorySQLiteStorage.swift
```

---

**빠른 시작**
현재 업로드된 구현 기준에서 SearchEngine 모듈은 **공개 초기화 진입점과 공개 계약을 먼저 제공하는 상태**입니다.
즉 상위 계층은 우선 `SearchEngineContainer`와 `SearchEngineConfiguration`을 통해 foundation을 초기화하고,
이후 공개 `SearchEngineProtocol` 구현체가 연결될 수 있는 기반을 준비하게 됩니다.

```swift
import SearchEngine

let container = try SearchEngineContainer.makeDefault()
print(container.configuration)
```

테스트나 샘플 실행처럼 디스크 저장소가 필요 없는 환경에서는 in-memory 구성이 더 간단합니다.

```swift
import SearchEngine

let container = try SearchEngineContainer.makeDefaultInMemory()
print(container.configuration)
```

특정 경로와 SQLite 정책을 직접 제어하고 싶다면 설정 객체를 먼저 생성한 뒤 컨테이너를 초기화할 수 있습니다.

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

let container = try SearchEngineContainer.make(configuration: configuration)
print(container.configuration)
```

---

**핵심 설계 방향**
SearchEngine 모듈은 다음 원칙을 기준으로 구성합니다.

- **외부 공개 계약과 내부 SQLite 구현 분리**
  - 상위 계층은 `Interface/Models`, `Interface/Errors`, `Interface/Protocols`에만 의존합니다.
  - `sqlite3`, FTS5 SQL, prepared statement, projection 관리 같은 세부 구현은 내부에 감춥니다.

- **조립 지점 통일**
  - 앱 또는 상위 모듈은 `SearchEngineContainer`를 통해 검색 엔진 foundation을 초기화합니다.
  - 구체 저장 구현체와 rebuild 경로는 동일한 SQLite foundation을 기준으로 조립되도록 정리합니다.

- **기능 책임 분리**
  - 문서 저장은 `SearchDocument Store`
  - 검색 실행은 `Search Store`
  - 자동완성은 `SearchSuggestion Store`
  - projection 복구는 `SearchRebuilder`
  - SQL 조립과 FTS 질의 문자열 생성은 `Support`
  - 값 변환은 `Mappers`

- **테스트 친화적인 구조**
  - 디스크 기반 live 설정뿐 아니라 in-memory SQLite 설정도 지원합니다.
  - Core / Interface / Mappers / StoreImplementations / Indexing 단위로 테스트를 분리해 기능 검증 경계를 명확히 유지합니다.

- **장기 확장을 고려한 로컬 검색 기반**
  - 현재는 SQLite + FTS5 기반 기본 검색 인프라와 rebuild 흐름을 제공하고,
    이후 tokenizer 전략, snippet 고도화, ranking 개선, 공개 엔진 조립 확장까지 이어질 수 있도록 foundation을 먼저 정리합니다.

---

**SearchEngineContainer**
`SearchEngineContainer`는 SearchEngine 모듈의 **조립 진입점(composition entry point)** 입니다.

제공 기능:
- `make(configuration:)`
- `makeDefault()`
- `makeDefaultInMemory()`

예시:
```swift
let configuration = try SearchEngineConfiguration.live()
let container = try SearchEngineContainer.make(configuration: configuration)
```

현재 업로드된 구현에서는 컨테이너가 내부적으로 같은 SQLite foundation을 재사용하는 저장 구현체와 rebuild 구현체를 조립하는 기반 역할을 담당합니다.
즉 문서 저장, 검색, suggestion, rebuild가 모두 같은 migration 규칙과 같은 SQLite 연결 정책 위에서 동작하도록 만드는 시작점입니다.

중요한 점:
- 현재 단계에서는 `SearchEngineProtocol`을 바로 반환하는 공개 엔진 팩토리는 아직 제공하지 않습니다.
- 즉 이 컨테이너는 **공개 초기화 기반** 역할에 집중합니다.
- 실제 공개 엔진 구현체는 이후 단계에서 이 foundation 위에 추가하는 방향이 자연스럽습니다.

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

### live 예시
```swift
let configuration = try SearchEngineConfiguration.live(
    directoryName: "SearchEngine",
    fileName: "SearchEngine.sqlite"
)
```

### in-memory 예시
```swift
let configuration = SearchEngineConfiguration.inMemory(
    identifier: "SearchEngine.InMemory"
)
```

또한 `databaseURL()`을 통해 디스크 저장소일 때 실제 SQLite 파일 경로를 계산할 수 있으며,
in-memory 구성에서는 `nil`을 반환합니다.

---

**Migration**
`SearchEngineMigrationPlan`은 SQLite 저장소를 열 때 적용할 migration 정책을 정의합니다.

기본 제공 정책:
- `SearchEngineMigrationPlan.sqliteCore`
- `SearchEngineMigrationPlan.searchIndexing`
- `SearchEngineMigrationPlan.disabled`

### sqliteCore
- 메타데이터 테이블 생성
- 최소 SQLite foundation 준비

### searchIndexing
- `sqliteCore` 포함
- documents 원본 테이블 생성
- scope + updatedAt 인덱스 생성
- FTS projection 테이블 생성

### disabled
- migration 미수행
- 이미 준비된 데이터베이스를 외부에서 관리하거나, migration 적용을 별도로 통제하는 환경에서 사용 가능

예시:
```swift
let configuration = try SearchEngineConfiguration.live(
    migrationPlan: .searchIndexing
)
```

중요한 점:
- migration 정책을 **결정하는 곳은 `SearchEngineConfiguration`** 입니다.
- `SQLiteStorage`와 `SQLiteDatabase`는 준비된 정책을 기준으로 저장소를 초기화합니다.
- 즉 migration은 실행 구현체 내부의 임시 분기보다 **configuration 기반 정책 주입**으로 관리합니다.

---

**SQLite foundation**
SearchEngine 모듈의 Core 계층은 SQLite 기반 foundation을 담당합니다.

주요 타입:
- `SQLiteDatabase`
- `SQLiteDatabaseProtocol`
- `SQLiteStorage`
- `SQLiteStorageProtocol`
- `SearchEngineMigrationSQL`

담당 역할:
- SQLite 연결 열기
- PRAGMA 적용
- migration 수행
- 공통 SQL 실행 경로 제공
- read / execute / transaction 경계 관리
- FTS projection 테이블을 포함한 초기 스키마 구성

상위 계층은 이 foundation을 직접 다루기보다,
공개 계약과 컨테이너를 중심으로 사용하는 구조가 더 적합합니다.

---

**공개 모델과 계약**
SearchEngine 모듈이 외부에 노출하는 주요 공개 타입은 다음과 같습니다.

### Models
- `SearchDocument`
- `SearchHit`
- `SearchQuery`
- `SearchScope`
- `SearchSnippet`
- `SearchSuggestion`
- `SearchSuggestionQuery`

### Errors
- `SearchEngineError`

### Protocols
- `SearchEngineProtocol`

이 구조의 목적은 다음과 같습니다.
- 상위 계층이 SQLite 내부 타입을 몰라도 된다.
- 로컬 검색 구현을 바꾸더라도 공개 계약은 안정적으로 유지할 수 있다.
- 이후 공개 엔진 구현체를 교체하거나 테스트 더블을 만들기 쉽다.

---

**현재 구현 기능**
현재 업로드된 SearchEngine 구현은 내부적으로 아래 기능을 포함합니다.

### 1. Document Indexing
문서를 원본 documents 테이블과 FTS projection에 함께 저장합니다.

특징:
- `SearchDocument` 검증 수행
- 같은 `id` 기준 upsert 저장
- 문서 삭제 시 원본 row와 projection row를 함께 제거
- 저장/삭제는 transaction 경계 안에서 처리하여 정합성 유지
- `scope`, `title`, `body`, `keywords`, `lastUpdatedAt`를 정규화해 저장

관련 내부 구현:
- `SQLiteSearchDocumentStore`
- `SearchDocumentMO`
- `SearchDocumentMapper`

### 2. Search
FTS 기반 검색 질의를 실행하고 `SearchHit` 목록을 반환합니다.

특징:
- `SearchQuery` 검증 수행
- `scope` 필터 지원
- `limit`, `offset` 지원
- 검색 결과는 `SearchDocument + score + snippet` 형태로 반환
- 내부적으로 FTS MATCH 질의와 정렬 정책을 사용

관련 내부 구현:
- `SQLiteSearchStore`
- `SearchHitMO`
- `SearchHitMapper`
- `SearchMatchQueryBuilder`

### 3. Suggestion
입력 중인 검색어에 대한 자동완성 결과를 생성합니다.

특징:
- `SearchSuggestionQuery` 검증 수행
- 현재 자동완성은 **title 컬럼 기반 token prefix MATCH** 전략 사용
- `scope` 필터 지원
- 같은 title/scope suggestion dedupe
- exact / prefix / contains 우선순위 반영
- 최신 문서와 정규화된 title 기준 정렬 보조 적용

관련 내부 구현:
- `SQLiteSearchSuggestionStore`
- `SearchSuggestionMO`
- `SearchSuggestionMapper`

### 4. Rebuild
원본 documents 테이블을 기준으로 FTS projection 전체를 다시 구성합니다.

특징:
- projection 손상 복구 경로 제공
- 원본 문서를 기준으로 projection 전체를 다시 적재
- projection delete + insert를 transaction 경계에서 수행
- 테스트, 장애 복구, migration 이후 정합성 확인에 적합

관련 내부 구현:
- `SearchRebuilder`
- `SearchProjectionMapper`

---

**Interface / ManagedObjects / Mapper / StoreImplementations / Support / Indexing**
SearchEngine 내부 구현은 아래 계층으로 나뉩니다.

### Interface
모듈 외부에 공개할 모델, 에러, 프로토콜을 정의합니다.

### ManagedObjects
SQLite row 결과를 내부에서 다루기 위한 ManagedObject 성격의 값 타입입니다.

예:
- `SearchDocumentMO`
- `SearchHitMO`
- `SearchSuggestionMO`

### Mappers
공개 모델과 ManagedObject 사이를 변환합니다.

예:
- `SearchDocumentMapper`
- `SearchHitMapper`
- `SearchSuggestionMapper`

### StoreImplementations
실제 SQLite 저장/검색/제안 로직을 구현합니다.

예:
- `SQLiteSearchDocumentStore`
- `SQLiteSearchStore`
- `SQLiteSearchSuggestionStore`

### Support
SQL 조립과 FTS 질의 문자열 생성을 보조합니다.

예:
- `SQLBuilder`
- `SearchMatchQueryBuilder`

### Indexing
projection 적재와 rebuild 같은 색인 유지/복구 역할을 담당합니다.

예:
- `SearchProjectionMapper`
- `SearchRebuilder`

이 구조 덕분에 공개 API, SQLite foundation, 검색 실행 로직, 색인 복구 로직의 경계를 비교적 안정적으로 유지할 수 있습니다.

---

**에러 모델**
SearchEngine 모듈은 `SearchEngineError`를 통해 검색 엔진 관련 오류를 일관되게 전달합니다.

주요 케이스:
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

상위 계층은 SQLite의 원시 에러 문자열을 직접 해석하기보다,
`SearchEngineError`를 기준으로 실패 원인을 분기하는 것이 좋습니다.

---

**테스트**
모듈은 in-memory SQLite 환경을 활용한 테스트를 포함합니다.

포함된 테스트 범위:
- `SQLiteDatabaseTests`
- `SQLiteStorageTests`
- `SearchEngineConfigurationTests`
- `SearchEngineMigrationPlanTests`
- `SearchEngineContainerTests`
- `SearchDocumentTests`
- `SearchQueryTests`
- `SearchScopeTests`
- `SearchSuggestionTests`
- `SearchSuggestionQueryTests`
- `SearchDocumentMapperTests`
- `SearchHitMapperTests`
- `SearchSuggestionMapperTests`
- `SQLiteSearchDocumentStoreTests`
- `SQLiteSearchStoreTests`
- `SQLiteSearchSuggestionStoreTests`
- `SearchProjectionMapperTests`
- `SearchRebuilderTests`
- `SQLBuilderTests`
- `SearchMatchQueryBuilderTests`

테스트 전략:
- Core foundation 테스트와 기능 테스트를 분리합니다.
- in-memory SQLite 환경으로 빠르고 독립적인 검증을 수행합니다.
- 문서 저장, 검색, suggestion, rebuild, query validation, mapper 변환, container 조립 결과를 함께 검증합니다.

---

**권장 사용 전략**
- 상위 계층은 `SearchEngineContainer`와 공개 계약 타입을 기준으로 의존성을 설계합니다.
- 화면/UseCase/Repository는 `SearchEngineProtocol`과 `Interface/Models` 중심으로 바라보는 방향이 적합합니다.
- `SQLiteDatabase`, `SQLiteStorage`, `StoreImplementations`, `Indexing` 직접 의존은 SearchEngine 내부에 제한하는 것이 좋습니다.
- 운영 환경은 `live`, 테스트와 샘플 실행은 `inMemory`를 우선 사용합니다.
- migration 정책은 `SearchEngineMigrationPlan`으로 환경별 분리 구성을 권장합니다.
- 현재 단계에서는 공개 엔진 구현체가 아직 없으므로, 외부 사용 README와 내부 개발 README를 구분해 관리하면 더 명확합니다.

---

**권장 확장 방식**
1. `Interface/Models`에 공개 모델 추가
2. `Interface/Protocols`에 공개 계약 추가 또는 세분화
3. `Core/SQL`에 migration SQL 추가
4. `SearchEngineMigrationPlan`에 버전 증가 반영
5. `ManagedObjects`에 내부 row 모델 추가
6. `Mappers`에 변환기 추가
7. `StoreImplementations`에 저장/검색 구현체 추가
8. `Support`에 SQL 조립기 또는 query builder 추가
9. `Indexing`에 projection 유지/복구 로직 추가
10. `SearchEngineContainer`에 공개 조립 경로 또는 엔진 팩토리 추가
11. 기능 전용 테스트 추가

---

Created by: JEONG, Chi-hong  
SearchEngine README draft adapted for current module state  
April 2026
