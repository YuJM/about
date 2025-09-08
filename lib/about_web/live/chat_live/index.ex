defmodule AboutWeb.ChatLive.Index do
  use AboutWeb, :live_view

  alias About.Chat

  @impl true
  def mount(_params, session, socket) do
    rooms = Chat.Room.list_public!()

    # 세션에서 닉네임과 세션 ID 가져오기
    nickname = Map.get(session, "chat_nickname")
    session_id = Map.get(session, "chat_session_id")

    {:ok,
     socket
     |> assign(:page_title, "채팅방 목록")
     |> assign(:rooms, rooms)
     |> assign(:show_modal, false)
     |> assign(:form, to_form(%{}))
     |> assign(:nickname, nickname)
     |> assign(:session_id, session_id)
     |> assign(:nickname_form, to_form(%{"nickname" => nickname || ""}))
     |> assign(:show_nickname_modal, is_nil(nickname))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:show_modal, true)
    |> assign(:form, to_form(%{"name" => "", "description" => ""}))
  end

  @impl true
  def handle_event("create_room", %{"room" => room_params}, socket) do
    # Convert "on" to boolean for is_public
    room_params =
      Map.update(room_params, "is_public", true, fn
        "on" -> true
        _ -> false
      end)

    case About.Chat.Room.create(room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "채팅방이 생성되었습니다.")
         |> assign(:show_modal, false)
         |> push_navigate(to: ~p"/chat/#{room.id}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "채팅방 생성에 실패했습니다.")}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_patch(to: ~p"/chat")}
  end

  @impl true
  def handle_event("set_nickname", %{"nickname" => %{"nickname" => nickname}}, socket) do
    nickname = String.trim(nickname)

    if nickname != "" do
      # 세션에 닉네임과 세션 ID 저장하기 위해 컨트롤러로 리다이렉트
      session_id = socket.assigns[:session_id] || Ash.UUID.generate()

      {:noreply,
       socket
       |> redirect(
         to: ~p"/chat/set_nickname?nickname=#{URI.encode(nickname)}&session_id=#{session_id}"
       )}
    else
      {:noreply, put_flash(socket, :error, "닉네임을 입력해주세요.")}
    end
  end

  @impl true
  def handle_event("change_nickname", _, socket) do
    {:noreply, assign(socket, :show_nickname_modal, true)}
  end

  @impl true
  def handle_event("set_session_id", %{"session_id" => session_id}, socket) do
    # 세션 ID를 저장하기 위해 클라이언트에 이벤트 전송
    {:noreply,
     socket
     |> assign(:session_id, session_id)
     |> push_event("save_session_id", %{session_id: session_id})}
  end

  @impl true
  def handle_event("enter_room", %{"room_id" => room_id}, socket) do
    if socket.assigns.nickname do
      {:noreply, push_navigate(socket, to: ~p"/chat/#{room_id}")}
    else
      {:noreply,
       socket
       |> assign(:show_nickname_modal, true)
       |> put_flash(:error, "먼저 닉네임을 설정해주세요.")}
    end
  end
end
