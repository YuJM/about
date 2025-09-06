defmodule AboutWeb.ChatLive.Index do
  use AboutWeb, :live_view
  
  alias About.Chat

  @impl true
  def mount(_params, _session, socket) do
    rooms = Chat.Room.list_public!()
    
    {:ok,
     socket
     |> assign(:page_title, "채팅방 목록")
     |> assign(:rooms, rooms)
     |> assign(:show_modal, false)
     |> assign(:form, to_form(%{}))}
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
    room_params = Map.update(room_params, "is_public", true, fn
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
end