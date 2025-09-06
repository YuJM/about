defmodule About.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        About.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:about, :token_signing_secret)
  end
end
