defmodule About.Repo.Migrations.RemoveUnusedOnlineStatusColumns do
  use Ecto.Migration

  def up do
    alter table(:chat_participants) do
      remove :is_online
      remove :last_seen_at
    end
  end

  def down do
    alter table(:chat_participants) do
      add :is_online, :boolean
      add :last_seen_at, :utc_datetime_usec
    end
  end
end
