# 📚 About 프로젝트 문서 인덱스

> Phoenix + Ash Framework 웹 애플리케이션 문서 모음

## 🗂️ 문서 구조

```
docs/
├── INDEX.md                      # 이 파일 (문서 인덱스)
├── ../CLAUDE.md                  # AI 개발 가이드
├── ../PROJECT_DOCUMENTATION.md   # 전체 프로젝트 문서
├── ../MODULE_RELATIONSHIPS.md    # 모듈 관계 및 의존성
├── ../DEVELOPMENT_WORKFLOW.md    # 개발 워크플로우 가이드
├── ../AGENTS.md                  # Phoenix 개발 가이드라인
└── ../README.md                  # 프로젝트 소개
```

## 📖 문서별 안내

### 🤖 [CLAUDE.md](../CLAUDE.md)
**대상**: Claude Code AI 인스턴스  
**내용**: 
- 프로젝트 개요 및 기술 스택
- 필수 개발 명령어
- 아키텍처 구조 설명
- Phoenix/Elixir/Ash 규칙
- 데이터베이스 및 배포 정보

### 📘 [PROJECT_DOCUMENTATION.md](../PROJECT_DOCUMENTATION.md)
**대상**: 개발자, 아키텍트  
**내용**:
- 전체 시스템 아키텍처
- 핵심 모듈 상세 설명
- 인증 시스템 구현
- API 및 라우팅 구조
- 데이터베이스 스키마
- 백그라운드 작업 시스템
- 프론트엔드 아키텍처
- 테스트 및 배포 가이드

### 🔗 [MODULE_RELATIONSHIPS.md](../MODULE_RELATIONSHIPS.md)
**대상**: 개발자, 유지보수 담당자  
**내용**:
- 모듈 의존성 그래프
- 상세 모듈 관계 분석
- 데이터 플로우 다이어그램
- 패키지 의존성 트리
- 모듈별 책임 정의
- 보안 경계 설명
- 성능 고려사항

### 🛠️ [DEVELOPMENT_WORKFLOW.md](../DEVELOPMENT_WORKFLOW.md)
**대상**: 개발자  
**내용**:
- 빠른 시작 가이드
- 일일 개발 워크플로우
- Ash 리소스 개발 방법
- LiveView 페이지 추가
- 인증 커스터마이징
- 백그라운드 작업 구현
- 테스트 작성 가이드
- 디버깅 팁

### 📋 [AGENTS.md](../AGENTS.md)
**대상**: Phoenix 개발자  
**내용**:
- Phoenix 1.8 가이드라인
- Elixir 베스트 프랙티스
- LiveView 개발 규칙
- UI/UX 디자인 가이드
- JS/CSS 가이드라인
- 테스트 작성 방법

### 📄 [README.md](../README.md)
**대상**: 모든 사용자  
**내용**:
- 프로젝트 소개
- 설치 및 실행 방법
- 기본 사용법
- 추가 학습 자료

## 🎯 용도별 문서 가이드

### 신규 개발자 온보딩
1. [README.md](../README.md) - 프로젝트 소개
2. [PROJECT_DOCUMENTATION.md](../PROJECT_DOCUMENTATION.md) - 시스템 이해
3. [DEVELOPMENT_WORKFLOW.md](../DEVELOPMENT_WORKFLOW.md) - 개발 시작
4. [AGENTS.md](../AGENTS.md) - 코딩 규칙 학습

### 기능 개발
1. [DEVELOPMENT_WORKFLOW.md](../DEVELOPMENT_WORKFLOW.md) - 워크플로우 확인
2. [MODULE_RELATIONSHIPS.md](../MODULE_RELATIONSHIPS.md) - 모듈 구조 파악
3. [AGENTS.md](../AGENTS.md) - 코딩 가이드라인 준수

### 버그 수정 및 디버깅
1. [MODULE_RELATIONSHIPS.md](../MODULE_RELATIONSHIPS.md) - 의존성 확인
2. [DEVELOPMENT_WORKFLOW.md](../DEVELOPMENT_WORKFLOW.md#디버깅) - 디버깅 방법
3. [PROJECT_DOCUMENTATION.md](../PROJECT_DOCUMENTATION.md) - 시스템 동작 이해

### 시스템 아키텍처 리뷰
1. [PROJECT_DOCUMENTATION.md](../PROJECT_DOCUMENTATION.md#아키텍처) - 전체 구조
2. [MODULE_RELATIONSHIPS.md](../MODULE_RELATIONSHIPS.md) - 상세 관계
3. [CLAUDE.md](../CLAUDE.md) - 기술 스택 및 패턴

## 🔄 문서 업데이트 가이드

### 문서 수정 시 체크리스트
- [ ] 관련된 다른 문서도 함께 업데이트
- [ ] 날짜 또는 버전 정보 갱신
- [ ] 목차 및 링크 유효성 확인
- [ ] 코드 예시 동작 확인
- [ ] 마크다운 포맷 검증

### 새 문서 추가 시
1. 적절한 위치에 문서 생성
2. 이 INDEX.md에 참조 추가
3. 관련 문서에서 상호 참조
4. CLAUDE.md에 중요 정보 반영

## 🏷️ 문서 태그

### 기술 레벨
- 🟢 **초급**: README, 빠른 시작
- 🟡 **중급**: DEVELOPMENT_WORKFLOW, AGENTS
- 🔴 **고급**: MODULE_RELATIONSHIPS, 아키텍처 섹션

### 업데이트 빈도
- **자주**: DEVELOPMENT_WORKFLOW (기능 추가 시)
- **가끔**: PROJECT_DOCUMENTATION (구조 변경 시)
- **드물게**: CLAUDE.md, AGENTS.md (규칙 변경 시)

### 중요도
- ⭐⭐⭐ **필수**: CLAUDE.md, PROJECT_DOCUMENTATION.md
- ⭐⭐ **중요**: DEVELOPMENT_WORKFLOW.md, MODULE_RELATIONSHIPS.md
- ⭐ **참고**: AGENTS.md, README.md

## 🔍 빠른 검색

### 주요 키워드
- **인증**: [PROJECT_DOCUMENTATION.md#인증-시스템](../PROJECT_DOCUMENTATION.md#인증-시스템)
- **데이터베이스**: [PROJECT_DOCUMENTATION.md#데이터베이스](../PROJECT_DOCUMENTATION.md#데이터베이스)
- **테스트**: [DEVELOPMENT_WORKFLOW.md#테스트-워크플로우](../DEVELOPMENT_WORKFLOW.md#테스트-워크플로우)
- **배포**: [PROJECT_DOCUMENTATION.md#배포](../PROJECT_DOCUMENTATION.md#배포)
- **Ash Framework**: [MODULE_RELATIONSHIPS.md](../MODULE_RELATIONSHIPS.md)
- **LiveView**: [AGENTS.md#phoenix-liveview-guidelines](../AGENTS.md)
- **Oban**: [PROJECT_DOCUMENTATION.md#백그라운드-작업](../PROJECT_DOCUMENTATION.md#백그라운드-작업)

### 명령어 참조
- **개발 명령어**: [CLAUDE.md#개발-명령어](../CLAUDE.md#개발-명령어)
- **Mix 태스크**: [DEVELOPMENT_WORKFLOW.md#유용한-mix-태스크](../DEVELOPMENT_WORKFLOW.md#유용한-mix-태스크)
- **테스트 명령어**: [DEVELOPMENT_WORKFLOW.md#통합-테스트](../DEVELOPMENT_WORKFLOW.md#통합-테스트)

## 📞 문서 관련 문의

문서에 대한 질문이나 개선 제안이 있으시면:
1. GitHub Issues에 등록
2. 문서 직접 수정 후 PR 제출
3. 팀 내부 채널로 문의

---

*최종 업데이트: 2025년 9월*  
*문서 버전: 1.0.0*