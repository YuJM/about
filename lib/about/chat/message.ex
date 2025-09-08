defmodule About.Chat.Message do
  use Ash.Resource,
    domain: About.Chat,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource]

  sqlite do
    table "chat_messages"
    repo About.Repo
  end

  admin do
    read_actions [:read]
    create_actions [:create]
    update_actions [:update]
    destroy_actions [:destroy]
  end

  code_interface do
    define :send
    define :edit
    define :soft_delete
    define :recent_messages
    define :list_by_room, args: [:room_id], action: :recent_messages
  end

  actions do
    defaults [:read, :destroy]

    create :send do
      accept [:content, :room_id, :participant_id]

      validate present(:content) do
        message "메시지 내용을 입력해주세요"
      end

      validate match(:content, ~r/\S/) do
        message "공백만으로는 메시지를 보낼 수 없습니다"
      end

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:type, :user)
      end
    end

    update :edit do
      accept [:content]
      require_atomic? false

      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :edited_at, DateTime.utc_now())
      end
    end

    update :soft_delete do
      require_atomic? false

      change fn changeset, _ ->
        changeset
        |> Ash.Changeset.change_attribute(:is_deleted, true)
        |> Ash.Changeset.change_attribute(:content, "[메시지가 삭제되었습니다]")
      end
    end

    read :recent_messages do
      argument :room_id, :uuid do
        allow_nil? false
      end

      argument :limit, :integer do
        default 100
      end

      filter expr(room_id == ^arg(:room_id) and is_deleted == false)

      prepare fn query, _ ->
        query
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.Query.load(:participant)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints max_length: 1000
    end

    attribute :type, :atom do
      constraints one_of: [:text, :system, :join, :leave, :user]
      default :text
    end

    attribute :edited_at, :utc_datetime_usec

    attribute :is_deleted, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :room, About.Chat.Room do
      allow_nil? false
    end

    belongs_to :participant, About.Chat.Participant do
      allow_nil? false
    end
  end
end
