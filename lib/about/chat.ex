defmodule About.Chat do
  use Ash.Domain, otp_app: :about, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource About.Chat.Room
    resource About.Chat.Message
    resource About.Chat.Participant
  end
end
