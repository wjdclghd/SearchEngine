//
//  SearchEngineError.swift
//  SearchEngine
//
//  Created by jch on 4/2/26.
//

import Foundation

/// SearchEngine 모듈 전반에서 공통으로 사용하는 에러 타입입니다.
///
/// 이 타입은 설정 검증, 문서/질의 검증, SQLite 연결 초기화,
/// statement 준비 및 실행, 읽기/쓰기/트랜잭션 실행 과정에서 발생할 수 있는 실패를
/// 하나의 도메인으로 정리하기 위해 사용합니다.
///
/// 상위 계층은 Foundation 또는 SQLite의 구체적인 에러 타입을 직접 해석하지 않고,
/// 이 타입을 기준으로 실패 원인을 분류할 수 있습니다.
public enum SearchEngineError: Error, Equatable, LocalizedError, Sendable {
    /// SearchEngine 구성을 만들기 위한 값이 올바르지 않거나,
    /// 실행에 필요한 필수 정보가 누락된 경우 발생합니다.
    ///
    /// - Parameter message: 잘못된 설정 내용 또는 누락된 항목을 설명하는 메시지입니다.
    case invalidConfiguration(message: String)

    /// 색인 대상 문서 값이 올바르지 않을 때 발생합니다.
    ///
    /// - Parameter message: 잘못된 문서 필드와 실패 원인을 설명하는 메시지입니다.
    case invalidDocument(message: String)

    /// 검색 또는 제안 질의 값이 올바르지 않을 때 발생합니다.
    ///
    /// - Parameter message: 잘못된 질의 조건과 실패 원인을 설명하는 메시지입니다.
    case invalidQuery(message: String)

    /// 데이터베이스 파일 경로를 구성할 수 없을 때 발생합니다.
    ///
    /// - Parameter message: 경로 생성 실패 원인을 설명하는 메시지입니다.
    case databasePathUnavailable(message: String)

    /// SQLite 데이터베이스 열기에 실패했을 때 발생합니다.
    ///
    /// - Parameter message: sqlite3_open_v2 또는 초기 pragma 적용 실패 원인을 설명하는 메시지입니다.
    case databaseOpenFailed(message: String)

    /// SQL statement 준비에 실패했을 때 발생합니다.
    ///
    /// - Parameters:
    ///   - sql: 준비에 실패한 SQL 문자열입니다.
    ///   - message: statement 준비 실패 원인을 설명하는 메시지입니다.
    case statementPreparationFailed(sql: String, message: String)

    /// SQL statement 실행에 실패했을 때 발생합니다.
    ///
    /// - Parameters:
    ///   - sql: 실행에 실패한 SQL 문자열입니다.
    ///   - message: statement 실행 실패 원인을 설명하는 메시지입니다.
    case statementExecutionFailed(sql: String, message: String)

    /// statement 바인딩에 실패했을 때 발생합니다.
    ///
    /// - Parameters:
    ///   - index: 실패한 parameter 인덱스입니다.
    ///   - message: 바인딩 실패 원인을 설명하는 메시지입니다.
    case statementBindingFailed(index: Int32, message: String)

    /// 마이그레이션 실행에 실패했을 때 발생합니다.
    ///
    /// - Parameter message: migration plan 검증 실패, 버전 불일치, SQL 적용 실패 원인을 설명하는 메시지입니다.
    case migrationFailed(message: String)

    /// 읽기 작업에 실패했을 때 발생합니다.
    ///
    /// - Parameter message: 읽기 작업 실패 원인을 설명하는 메시지입니다.
    case readFailed(message: String)

    /// 쓰기 작업에 실패했을 때 발생합니다.
    ///
    /// - Parameter message: 쓰기 작업 또는 저장 실패 원인을 설명하는 메시지입니다.
    case writeFailed(message: String)

    /// 트랜잭션 실행에 실패했을 때 발생합니다.
    ///
    /// - Parameter message: 트랜잭션 시작, commit, rollback 또는 내부 작업 실패 원인을 설명하는 메시지입니다.
    case transactionFailed(message: String)

    /// 사용자 표시용 에러 설명을 제공합니다.
    ///
    /// 로깅, 디버깅, 상위 계층 전달 시 실패 원인을
    /// 일관된 문장으로 확인할 수 있도록 구성합니다.
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            return "SearchEngine 설정이 올바르지 않습니다. \(message)"

        case let .invalidDocument(message):
            return "색인 문서 값이 올바르지 않습니다. \(message)"

        case let .invalidQuery(message):
            return "검색 질의 값이 올바르지 않습니다. \(message)"

        case let .databasePathUnavailable(message):
            return "SQLite 데이터베이스 경로를 구성할 수 없습니다. \(message)"

        case let .databaseOpenFailed(message):
            return "SQLite 데이터베이스를 열지 못했습니다. \(message)"

        case let .statementPreparationFailed(sql, message):
            return "SQL statement 준비에 실패했습니다. sql: \(sql), \(message)"

        case let .statementExecutionFailed(sql, message):
            return "SQL statement 실행에 실패했습니다. sql: \(sql), \(message)"

        case let .statementBindingFailed(index, message):
            return "SQL statement 바인딩에 실패했습니다. index: \(index), \(message)"

        case let .migrationFailed(message):
            return "SQLite migration 실행에 실패했습니다. \(message)"

        case let .readFailed(message):
            return "읽기 작업에 실패했습니다. \(message)"

        case let .writeFailed(message):
            return "쓰기 작업에 실패했습니다. \(message)"

        case let .transactionFailed(message):
            return "트랜잭션 실행에 실패했습니다. \(message)"
        }
    }
}
