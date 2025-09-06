defmodule AboutWeb.PageController do
  use AboutWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
