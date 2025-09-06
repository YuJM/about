defmodule AboutWeb.ChatController do
  use AboutWeb, :controller

  def set_nickname(conn, params) do
    # URL 디코딩 처리
    decoded_nickname = URI.decode(params["nickname"] || "")
    session_id = params["session_id"] || Ash.UUID.generate()
    
    conn
    |> put_session("chat_nickname", decoded_nickname)
    |> put_session("chat_session_id", session_id)
    |> put_flash(:info, "닉네임이 설정되었습니다.")
    |> redirect(to: ~p"/chat")
  end
end