defmodule About.Accounts do
  use Ash.Domain, otp_app: :about, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource About.Accounts.Token
    resource About.Accounts.User
  end
end
