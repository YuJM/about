defmodule AboutWeb.ChatPresence do
  @moduledoc """
  채팅방 실시간 참여자 추적을 위한 Phoenix Presence 구현
  
  온라인/오프라인 상태는 완전히 Presence로만 관리하며, DB에는 저장하지 않습니다.
  사용자가 채팅방에 연결/해제될 때 자동으로 presence 상태를 관리하고
  브라우저 종료나 네트워크 단절 시 자동으로 참여자 목록에서 제거됩니다.
  """
  
  use Phoenix.Tracker
  
  def start_link(opts) do
    opts = Keyword.merge([name: __MODULE__], opts)
    Phoenix.Tracker.start_link(__MODULE__, opts, opts)
  end
  
  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{
      pubsub_server: server,
      node_name: Phoenix.PubSub.node_name(server)
    }}
  end
  
  def handle_diff(diff, state) do
    for {topic, {joins, leaves}} <- diff do
      for {key, meta} <- joins do
        msg = {:presence_join, key, meta}
        Phoenix.PubSub.direct_broadcast!(
          state.node_name,
          state.pubsub_server,
          topic,
          msg
        )
      end
      
      for {key, meta} <- leaves do
        msg = {:presence_leave, key, meta}
        Phoenix.PubSub.direct_broadcast!(
          state.node_name,
          state.pubsub_server,
          topic,
          msg
        )
      end
    end
    
    {:ok, state}
  end
  
  @doc """
  채팅방에 참여자 추가 (온라인 상태 시작)
  """
  def track_participant(room_id, participant_id, meta \\ %{}) do
    enhanced_meta = 
      meta
      |> Map.put(:joined_at, DateTime.utc_now())
      |> Map.put(:node, Node.self())
    
    Phoenix.Tracker.track(__MODULE__, self(), room_topic(room_id), participant_id, enhanced_meta)
  end
  
  @doc """
  채팅방에서 참여자 제거 (오프라인 상태)
  """
  def untrack_participant(room_id, participant_id) do
    Phoenix.Tracker.untrack(__MODULE__, self(), room_topic(room_id), participant_id)
  end
  
  @doc """
  참여자 메타데이터 업데이트 (닉네임 변경 등)
  """
  def update_participant(room_id, participant_id, meta_updates) do
    Phoenix.Tracker.update(__MODULE__, self(), room_topic(room_id), participant_id, fn existing_meta ->
      Map.merge(existing_meta, meta_updates)
    end)
  end
  
  @doc """
  채팅방의 현재 온라인 참여자 목록 조회
  """
  def list_participants(room_id) do
    Phoenix.Tracker.list(__MODULE__, room_topic(room_id))
  end
  
  @doc """
  채팅방의 온라인 참여자를 메타데이터와 함께 조회
  """
  def list_participants_with_meta(room_id) do
    Phoenix.Tracker.list(__MODULE__, room_topic(room_id))
    |> Enum.map(fn {participant_id, meta} ->
      %{
        id: participant_id,
        nickname: meta[:nickname],
        color: meta[:color],
        joined_at: meta[:joined_at],
        participant: meta[:participant]
      }
    end)
  end
  
  @doc """
  특정 참여자가 온라인인지 확인
  """
  def participant_online?(room_id, participant_id) do
    case Phoenix.Tracker.get_by_key(__MODULE__, room_topic(room_id), participant_id) do
      [] -> false
      _ -> true
    end
  end
  
  @doc """
  특정 참여자의 메타데이터 조회
  """
  def get_participant_meta(room_id, participant_id) do
    case Phoenix.Tracker.get_by_key(__MODULE__, room_topic(room_id), participant_id) do
      [] -> nil
      [{_pid, meta}] -> meta
      metas when is_list(metas) -> 
        # 여러 프로세스에서 같은 참여자를 추적하는 경우 최신 메타 반환
        metas 
        |> Enum.map(fn {_pid, meta} -> meta end)
        |> Enum.max_by(& &1[:joined_at], DateTime)
    end
  end
  
  @doc """
  채팅방의 온라인 참여자 수 조회
  """
  def participant_count(room_id) do
    Phoenix.Tracker.list(__MODULE__, room_topic(room_id))
    |> Enum.count()
  end
  
  @doc """
  모든 채팅방의 상태 조회 (관리자용) - 개별 토픽들 조회
  """
  def list_all_rooms do
    # 직접 모든 토픽을 가져오는 대신, 각 토픽별로 조회
    # 실제 사용시에는 활성 채팅방 목록을 별도로 관리하는 것이 좋습니다
    []
  end
  
  defp room_topic(room_id), do: "chat_room:#{room_id}"
end