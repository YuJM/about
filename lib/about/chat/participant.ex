defmodule About.Chat.Participant do
  use Ash.Resource,
    domain: About.Chat,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource]

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

  attributes do
    uuid_primary_key :id

    attribute :nickname, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :color, :string do
      default "#" <> :crypto.strong_rand_bytes(3) |> Base.encode16()
    end

    attribute :is_online, :boolean do
      default true
    end

    attribute :last_seen_at, :utc_datetime_usec do
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

    update :update_status do
      accept [:is_online, :last_seen_at]
    end

    update :change_nickname do
      accept [:nickname]
    end

    action :leave_room, :boolean do
      argument :participant_id, :uuid do
        allow_nil? false
      end

      run fn input, _ ->
        case About.Chat.Participant.get(input.arguments.participant_id) do
          {:ok, participant} ->
            participant
            |> Ash.Changeset.for_update(:update_status, %{
              is_online: false,
              last_seen_at: DateTime.utc_now()
            })
            |> About.Chat.update()
            
            {:ok, true}
            
          _ ->
            {:ok, false}
        end
      end
    end
  end

  code_interface do
    define :join_room
    define :leave_room
    define :update_status
  end
end