# About

실시간 채팅과 회고 대화를 지원하는 Phoenix + Ash 기반 웹 애플리케이션입니다.
본 문서는 로컬 개발, 테스트, 배포, 프로젝트 규칙을 간결하게 안내합니다.

## 빠른 시작

1. 의존성 및 초기 설정
   - `mix setup`
2. 개발 서버 실행
   - `mix phx.server` 또는 `iex -S mix phx.server`
3. 접속
   - 브라우저에서 `http://localhost:4000`

## 개발 가이드

- 코드 검사/테스트 사전 훅: 작업 완료 후 반드시 `mix precommit` 실행
- HTTP 클라이언트: `Req` 라이브러리 사용 (기본 포함). `:httpoison`, `:tesla`, `:httpc` 사용 금지

### Phoenix v1.8 사용 규칙 요약

- 모든 LiveView 템플릿은 항상 `<Layouts.app flash={@flash} ...>`로 시작해 래핑
- `current_scope` 관련 오류가 나면 라우터의 인증 세션 위치와 `<Layouts.app>` 전달값을 점검해 수정
- `<.flash_group>`는 `Layouts` 모듈 내부에서만 사용
- 아이콘은 `core_components.ex`의 `<.icon>`만 사용
- 폼 입력은 `core_components.ex`의 `<.input>` 사용 권장

### JS/CSS

- Tailwind CSS v4 사용. `assets/css/app.css`는 다음 임포트를 유지
  - `@import "tailwindcss" source(none);`
  - `@source "../css";`, `@source "../js";`, `@source "../../lib/about_web";`
- DaisyUI 사용: `assets/css/app.css` 내 `@plugin "../vendor/daisyui"`
- 번들: `app.js`, `app.css`만 사용. 외부 스크립트/링크 직접 참조 금지 (모두 번들에 임포트)

### LiveView

- `push_navigate`/`push_patch` 및 `<.link navigate|patch>` 사용 (구 `live_redirect`/`live_patch` 금지)
- 리스트 렌더링은 Stream API 사용 및 템플릿에 `phx-update="stream"` 적용

## 명령어 치트시트

- 의존성/셋업: `mix setup`
- 개발 서버: `mix phx.server`
- 자산 번들: `mix assets.build`
- 배포용 자산: `mix assets.deploy`
- 테스트: `mix test`
- 사전 점검: `mix precommit`

## 배포

- Phoenix 배포 가이드: [hexdocs Phoenix Deployment](https://hexdocs.pm/phoenix/deployment.html)
- 정적 자산 빌드 후 다이제스트: `mix assets.deploy && MIX_ENV=prod mix phx.digest`

## 참고 링크

- Phoenix 공식: [phoenixframework.org](https://www.phoenixframework.org/)
- Guides: [hexdocs Phoenix Overview](https://hexdocs.pm/phoenix/overview.html)
- Docs: [hexdocs Phoenix](https://hexdocs.pm/phoenix)
- Forum: [Elixir Forum / Phoenix](https://elixirforum.com/c/phoenix-forum)
- Source: [github.com/phoenixframework/phoenix](https://github.com/phoenixframework/phoenix)
