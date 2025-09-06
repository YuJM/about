# 개발 워크플로우 가이드

## 🚀 빠른 시작

### 초기 설정
```bash
# 프로젝트 클론
git clone <repository-url> about
cd about

# 의존성 설치 및 초기 설정
mix setup

# 개발 서버 시작
iex -S mix phx.server

# 브라우저에서 확인
open http://localhost:4000
```

## 📋 일일 개발 워크플로우

### 1. 작업 시작
```bash
# 최신 코드 가져오기
git pull origin master

# 새 기능 브랜치 생성
git checkout -b feature/user-profile

# 의존성 업데이트 확인
mix deps.get
```

### 2. 개발 중
```bash
# 서버 실행 (자동 리로드 포함)
iex -S mix phx.server

# 별도 터미널에서 테스트 감시
mix test.watch  # ExUnit 확장 필요 시

# 코드 포맷팅 (저장 시마다)
mix format
```

### 3. 커밋 전
```bash
# 전체 검증 실행
mix precommit

# 개별 검증 (필요시)
mix compile --warnings-as-errors
mix format --check-formatted
mix test
mix deps.unlock --unused
```

## 🔧 주요 개발 작업

### Ash 리소스 추가

#### 1. 새 리소스 생성
```bash
# 도메인 생성 (필요시)
mix ash.gen.domain Billing

# 리소스 생성
mix ash.gen.resource Billing Invoice \
  --attributes "invoice_number:string:required,amount:decimal:required,status:atom"
```

#### 2. 리소스 정의
```elixir
# lib/about/billing/invoice.ex
defmodule About.Billing.Invoice do
  use Ash.Resource,
    domain: About.Billing,
    data_layer: AshSqlite.DataLayer
    
  sqlite do
    table "invoices"
    repo About.Repo
  end
  
  attributes do
    uuid_primary_key :id
    attribute :invoice_number, :string, allow_nil?: false
    attribute :amount, :decimal, allow_nil?: false
    attribute :status, :atom do
      constraints one_of: [:draft, :sent, :paid, :cancelled]
      default :draft
    end
    timestamps()
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :create do
      accept [:invoice_number, :amount]
    end
    
    update :update do
      accept [:status]
    end
    
    action :mark_as_paid, :atom do
      run fn input, _ ->
        input.resource
        |> Ash.Changeset.for_update(:update, %{status: :paid})
        |> About.Billing.update()
      end
    end
  end
end
```

#### 3. 도메인에 등록
```elixir
# lib/about/billing.ex
defmodule About.Billing do
  use Ash.Domain
  
  resources do
    resource About.Billing.Invoice
  end
end
```

#### 4. 마이그레이션 생성 및 실행
```bash
# 마이그레이션 생성
mix ash.generate_migrations --name add_invoices

# 마이그레이션 실행
mix ash.migrate
```

### LiveView 페이지 추가

#### 1. LiveView 모듈 생성
```elixir
# lib/about_web/live/invoice_live/index.ex
defmodule AboutWeb.InvoiceLive.Index do
  use AboutWeb, :live_view
  
  on_mount {AboutWeb.LiveUserAuth, :live_user_required}
  
  @impl true
  def mount(_params, _session, socket) do
    invoices = About.Billing.Invoice.read!()
    
    {:ok, 
     socket
     |> assign(:page_title, "Invoices")
     |> stream(:invoices, invoices)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app>
      <div class="container mx-auto p-6">
        <h1 class="text-3xl font-bold mb-6">Invoices</h1>
        
        <div id="invoices" phx-update="stream" class="space-y-4">
          <div :for={{id, invoice} <- @streams.invoices} id={id} 
               class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">{invoice.invoice_number}</h2>
              <p>Amount: ${invoice.amount}</p>
              <p>Status: {invoice.status}</p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

#### 2. 라우터에 추가
```elixir
# lib/about_web/router.ex
scope "/" do
  pipe_through :browser
  
  ash_authentication_live_session :authenticated_routes do
    live "/invoices", InvoiceLive.Index, :index
    live "/invoices/new", InvoiceLive.New, :new
    live "/invoices/:id", InvoiceLive.Show, :show
  end
end
```

### 인증 커스터마이징

#### 1. 새 인증 전략 추가
```elixir
# lib/about/accounts/user.ex
authentication do
  strategies do
    # 기존 password 전략...
    
    # OAuth 추가
    oauth2 :github do
      client_id About.Secrets
      client_secret About.Secrets
      redirect_uri About.Secrets
      authorization_params [scope: "user:email"]
    end
  end
end
```

#### 2. 인증 UI 커스터마이징
```elixir
# lib/about_web/auth_overrides.ex
defmodule AboutWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides
  
  override AshAuthentication.Phoenix.Components do
    def sign_in_form(assigns) do
      ~H"""
      <div class="auth-container custom-styles">
        <!-- 커스텀 로그인 폼 -->
      </div>
      """
    end
  end
end
```

### 백그라운드 작업 추가

#### 1. Worker 생성
```elixir
# lib/about/workers/invoice_reminder.ex
defmodule About.Workers.InvoiceReminder do
  use Oban.Worker, queue: :mailers, max_attempts: 3
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invoice_id" => invoice_id}}) do
    invoice = About.Billing.Invoice.get!(invoice_id)
    
    # 이메일 전송 로직
    About.Mailer.send_reminder(invoice)
    
    :ok
  end
end
```

#### 2. 작업 예약
```elixir
# 즉시 실행
%{invoice_id: invoice.id}
|> About.Workers.InvoiceReminder.new()
|> Oban.insert()

# 지연 실행
%{invoice_id: invoice.id}
|> About.Workers.InvoiceReminder.new(scheduled_at: ~U[2024-12-01 09:00:00Z])
|> Oban.insert()

# Cron 작업 (config.exs)
config :about, Oban,
  plugins: [
    {Oban.Plugins.Cron, [
      crontab: [
        {"0 9 * * *", About.Workers.DailyReminder}
      ]
    ]}
  ]
```

## 🧪 테스트 워크플로우

### 단위 테스트
```elixir
# test/about/billing_test.exs
defmodule About.BillingTest do
  use About.DataCase
  
  describe "invoices" do
    test "creates invoice with valid data" do
      assert {:ok, invoice} = 
        About.Billing.Invoice
        |> Ash.Changeset.for_create(:create, %{
          invoice_number: "INV-001",
          amount: Decimal.new("100.00")
        })
        |> About.Billing.create()
        
      assert invoice.invoice_number == "INV-001"
      assert invoice.status == :draft
    end
  end
end
```

### LiveView 테스트
```elixir
# test/about_web/live/invoice_live_test.exs
defmodule AboutWeb.InvoiceLiveTest do
  use AboutWeb.ConnCase
  import Phoenix.LiveViewTest
  
  setup :register_and_log_in_user
  
  test "lists all invoices", %{conn: conn} do
    invoice = invoice_fixture()
    
    {:ok, view, html} = live(conn, ~p"/invoices")
    
    assert html =~ "Invoices"
    assert has_element?(view, "#invoice-#{invoice.id}")
  end
  
  test "creates new invoice", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/invoices/new")
    
    assert view
           |> form("#invoice-form", invoice: %{
             invoice_number: "INV-002",
             amount: "200.00"
           })
           |> render_submit()
           
    assert_redirected(view, ~p"/invoices")
  end
end
```

### 통합 테스트
```bash
# 전체 테스트 실행
mix test

# 특정 파일 테스트
mix test test/about_web/live/invoice_live_test.exs

# 특정 라인 테스트
mix test test/about_web/live/invoice_live_test.exs:15

# 태그별 테스트
mix test --only integration

# 실패한 테스트만
mix test --failed
```

## 🐛 디버깅

### IEx 디버깅
```elixir
# 코드에 중단점 추가
require IEx
IEx.pry()

# IEx에서 직접 실행
iex> About.Billing.Invoice.read!()
iex> invoice = About.Billing.Invoice.get!("uuid")
iex> Ash.Changeset.for_update(invoice, :update, %{status: :paid})
```

### LiveView 디버깅
```elixir
# LiveView 프로세스 상태 확인
{:ok, view, _} = live(conn, "/invoices")
:sys.get_state(view.pid)

# 소켓 상태 출력
def handle_event("click", _, socket) do
  IO.inspect(socket.assigns, label: "Socket assigns")
  {:noreply, socket}
end
```

### 데이터베이스 디버깅
```elixir
# SQL 로깅 활성화 (dev.exs)
config :about, About.Repo,
  log: :debug

# Ecto 쿼리 확인
query = About.Billing.Invoice
        |> Ash.Query.filter(status == :draft)
        
About.Repo.to_sql(:all, query)
```

## 📝 코드 스타일 가이드

### Elixir 컨벤션
```elixir
# 모듈 구조
defmodule About.Billing.Invoice do
  # use 문
  use Ash.Resource
  
  # import/alias/require
  import Ecto.Query
  alias About.Repo
  
  # 모듈 속성
  @timeout 5_000
  
  # Ash DSL
  attributes do
    # ...
  end
  
  # 공개 함수
  def public_function do
    # ...
  end
  
  # 비공개 함수
  defp private_function do
    # ...
  end
end
```

### Phoenix 컨벤션
```elixir
# 컨트롤러 액션
def show(conn, %{"id" => id}) do
  invoice = About.Billing.Invoice.get!(id)
  render(conn, :show, invoice: invoice)
end

# LiveView 콜백
@impl true
def mount(params, session, socket) do
  # mount 로직
end

@impl true
def handle_event(event, params, socket) do
  # 이벤트 처리
end
```

## 🚢 배포 준비

### 1. 프로덕션 체크리스트
```bash
# 환경 변수 확인
export MIX_ENV=prod
export DATABASE_URL=...
export SECRET_KEY_BASE=...

# 의존성 컴파일
mix deps.get --only prod
mix compile

# 자산 빌드
mix assets.deploy

# 마이그레이션 확인
mix ecto.migrate --log-sql

# 릴리즈 생성
mix release
```

### 2. 성능 최적화
```elixir
# config/prod.exs
config :about, AboutWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  gzip: true,
  compress: true

config :phoenix, :serve_endpoints, true
config :logger, level: :warning
```

### 3. 모니터링 설정
```elixir
# Telemetry 이벤트
:telemetry.attach(
  "invoice-created",
  [:about, :billing, :invoice, :created],
  &About.Telemetry.handle_event/4,
  nil
)
```

## 📚 참고 자료

### 도구 및 확장
- [ElixirLS](https://github.com/elixir-lsp/elixir-ls) - VSCode 확장
- [Credo](https://github.com/rrrene/credo) - 코드 분석
- [Dialyxir](https://github.com/jeremyjh/dialyxir) - 정적 분석
- [ExDoc](https://github.com/elixir-lang/ex_doc) - 문서 생성

### 유용한 Mix 태스크
```bash
mix help                    # 사용 가능한 태스크 목록
mix ash.gen.resource       # Ash 리소스 생성
mix phx.gen.live          # LiveView 생성
mix phx.routes            # 라우트 목록
mix format                # 코드 포맷팅
mix test --cover          # 테스트 커버리지
```

---

*이 문서는 효율적인 개발 워크플로우를 위한 가이드입니다. 팀의 필요에 따라 수정하여 사용하세요.*