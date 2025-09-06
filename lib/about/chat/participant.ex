defmodule About.Chat.Participant do
  use Ash.Resource,
    domain: About.Chat,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  sqlite do
    table "chat_participants"
    repo About.Repo
  end

  admin do
    read_actions [:read]
    create_actions [:create]
    update_actions [:update]
    destroy_actions [:destroy]
  end

  pub_sub do
    module AboutWeb.Endpoint
    prefix "participant"
    
    publish :join_room, ["joined", :room_id]
    publish :change_nickname, ["nickname_changed", :room_id, :id]
    publish :destroy, ["left", :room_id]
  end

  attributes do
    uuid_primary_key :id

    attribute :nickname, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :color, :string do
      default "#" <> :crypto.strong_rand_bytes(3) |> Base.encode16()
    end

    # 영속적 참여 기록만 유지 (실시간 상태는 제거)
    attribute :joined_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
    end

    timestamps()
  end

  relationships do
    belongs_to :room, About.Chat.Room do
      allow_nil? false
    end

    belongs_to :user, About.Accounts.User do
      allow_nil? true
    end

    has_many :messages, About.Chat.Message do
      destination_attribute :participant_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :join_room do
      accept [:nickname, :room_id, :user_id]
    end

    update :change_nickname do
      accept [:nickname]
    end

    # 실시간 상태 관련 액션들 제거
    # - update_status 제거
    # - leave_room 제거 (Presence가 자동 처리)
  end

  code_interface do
    define :join_room
    define :change_nickname
  end
end