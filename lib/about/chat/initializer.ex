defmodule About.Chat.Initializer do
  @moduledoc """
  Pure Presence 기반 채팅 시스템에서는 온라인 상태를 DB에 저장하지 않으므로
  초기화 시 별도의 작업이 필요하지 않습니다.

  온라인/오프라인 상태는 Phoenix Presence로 완전히 관리됩니다.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Pure Presence 시스템에서는 초기화 시 DB 상태 업데이트 불필요
    IO.puts("Chat Initializer: Pure Presence system initialized - no DB status updates needed")
    {:ok, %{}}
  end
end
