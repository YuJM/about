defmodule About.Chat.Room do
  use Ash.Resource,
    domain: About.Chat,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource]

  sqlite do
    table "chat_rooms"
    repo About.Repo
  end

  admin do
    read_actions [:read]
    create_actions [:create]
    update_actions [:update]
    destroy_actions [:destroy]
  end

  code_interface do
    define :get, action: :read, get?: true
    define :create
    define :list_public
    define :get_with_messages
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :is_public, :max_participants]
    end

    update :update do
      accept [:name, :description, :is_public, :max_participants]
    end

    read :list_public do
      filter expr(is_public == true)
    end

    read :get_with_messages do
      argument :limit, :integer, default: 100

      prepare fn query, _ ->
        query
        |> Ash.Query.load(messages: [:participant])
        |> Ash.Query.limit_relationship(:messages, {:arg, :limit})
        |> Ash.Query.sort_relationship(:messages, inserted_at: :desc)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :is_public, :boolean do
      default true
    end

    attribute :max_participants, :integer do
      default 100
    end

    timestamps()
  end

  relationships do
    has_many :messages, About.Chat.Message do
      destination_attribute :room_id
    end

    has_many :participants, About.Chat.Participant do
      destination_attribute :room_id
    end
  end
end
