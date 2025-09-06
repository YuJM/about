# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

이것은 Phoenix 1.8 웹 프레임워크와 Ash Framework를 사용하는 Elixir 애플리케이션입니다. Ash Authentication을 통한 인증, Oban을 통한 백그라운드 작업, SQLite3 데이터베이스를 사용합니다.

## 개발 명령어

### 주요 명령어

```bash
# 프로젝트 설정 및 의존성 설치
mix setup

# Phoenix 서버 시작
mix phx.server
# 또는 IEx 셸과 함께
iex -S mix phx.server

# 테스트 실행
mix test
# 특정 파일 테스트
mix test test/path/to/test.exs
# 실패한 테스트만 재실행
mix test --failed

# 커밋 전 모든 검증 실행 (컴파일, 포맷팅, 테스트)
mix precommit

# 데이터베이스 작업
mix ecto.create    # DB 생성
mix ecto.migrate   # 마이그레이션 실행
mix ecto.reset     # DB 리셋 (drop + setup)
mix ash.setup      # Ash 리소스 설정

# 자산 빌드
mix assets.build   # JS와 CSS 빌드
mix assets.deploy  # 프로덕션용 최적화 빌드

# 코드 포맷팅
mix format
```

### 개발 URL

- 메인 애플리케이션: http://localhost:4000
- LiveDashboard: http://localhost:4000/dev/dashboard
- Oban Dashboard: http://localhost:4000/oban
- Ash Admin: http://localhost:4000/admin
- Mailbox Preview: http://localhost:4000/dev/mailbox

## 아키텍처 구조

### 핵심 모듈 구조

```
lib/
├── about/                 # 비즈니스 로직 (컨텍스트)
│   ├── accounts/         # Ash 도메인 - 사용자 인증
│   │   ├── user.ex      # User 리소스 (Ash.Resource)
│   │   └── token.ex     # Token 리소스
│   ├── accounts.ex       # Ash Domain 정의
│   ├── application.ex    # OTP Application 시작점
│   ├── repo.ex          # Ecto Repo
│   └── secrets.ex       # 암호화 설정 (Cloak)
│
└── about_web/            # 웹 레이어
    ├── router.ex        # 라우팅 (인증 라우트 포함)
    ├── endpoint.ex      # Phoenix Endpoint
    ├── live_user_auth.ex # LiveView 인증 hooks
    └── auth_overrides.ex # 인증 UI 커스터마이징
```

### Ash Framework 패턴

- **Domain**: `About.Accounts` - 리소스를 그룹화하는 경계 컨텍스트
- **Resource**: `About.Accounts.User`, `About.Accounts.Token` - 데이터 모델과 액션 정의
- **Actions**: Ash 리소스 내에서 정의되는 CRUD 및 커스텀 작업
- **Authentication**: AshAuthentication을 통한 전체 인증 시스템 (magic link, password, confirmation 지원)

### 인증 시스템

- AshAuthentication.Phoenix를 사용한 완전한 인증 플로우
- 지원 전략: password, magic_link, confirmation
- LiveView 인증: `AboutWeb.LiveUserAuth` 모듈의 on_mount hooks 사용
  - `:live_user_required` - 인증 필수
  - `:live_user_optional` - 인증 선택
  - `:live_no_user` - 비인증 사용자만

### 백그라운드 작업

- Oban을 통한 작업 큐 시스템
- AshOban 통합으로 Ash 액션과 연동
- Oban.Web을 통한 웹 대시보드 제공

## 중요 개발 가이드라인

상세한 Phoenix, Elixir, LiveView 개발 가이드라인은 [AGENTS.md](./AGENTS.md)를 참조하세요.

### 주요 규칙 요약

- **Phoenix/LiveView**: `<Layouts.app>` 사용, `AboutWeb.*Live` 네이밍, Stream 사용
- **Elixir**: `:req` 라이브러리 사용, `Enum.at/2`로 리스트 접근, `cond`/`case` 사용
- **Ash Framework**: 리소스 변경 시 `mix ash.setup`, 자동 마이그레이션 생성
- **테스트**: `Phoenix.LiveViewTest`와 `LazyHTML` 사용, 요소 선택자 기반 테스트

### 자산 관리

- Tailwind CSS v4 사용 (config 파일 불필요)
- ESBuild를 통한 JS 번들링
- app.js와 app.css만 지원 (vendor 스크립트는 import 필요)

### UI/스타일링 시스템

- **CSS 프레임워크**: Tailwind CSS v4 (베이스)
  - `@import "tailwindcss"` 새로운 v4 문법 사용
  - `@source` 디렉티브로 소스 파일 스캔
- **UI 컴포넌트**: daisyUI (Tailwind 플러그인)
  - `@plugin "../vendor/daisyui"` 로 로드
  - 테마 시스템 사용 가능 (현재 `themes: false`)
- **아이콘**: Heroicons
  - `<.icon name="hero-*" />` 컴포넌트 사용
  - `@plugin "../vendor/heroicons"` 로 클래스 생성
  - 예시: `<.icon name="hero-x-mark" />`, `<.icon name="hero-arrow-path" />`
- **컴포넌트 시스템**: `AboutWeb.CoreComponents`
  - Phoenix.Component 기반
  - flash, button, input, icon 등 기본 컴포넌트 제공

## 데이터베이스

- SQLite3 사용 (개발: about_dev.db)
- Ecto.Migrator가 자동으로 마이그레이션 실행
- Ash 리소스 변경 시 마이그레이션 자동 생성 가능

## 배포 고려사항

- `mix assets.deploy` - 프로덕션 자산 빌드
- 환경 변수 설정 필요 (config/runtime.exs 참조)
- SQLite 마이그레이션은 릴리즈 모드에서 자동 실행
