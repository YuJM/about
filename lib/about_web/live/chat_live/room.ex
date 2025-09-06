defmodule AboutWeb.ChatLive.Room do
  use AboutWeb, :live_view
  
  require Ash.Query
  
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    case Ash.get(About.Chat.Room, room_id, domain: About.Chat) do
      {:ok, room} ->
        if connected?(socket) do
          PubSub.subscribe(About.PubSub, "room:#{room_id}")
          send(self(), :load_messages)
        end
        
        {:ok,
         socket
         |> assign(:page_title, room.name)
         |> assign(:room, room)
         |> assign(:current_participant, nil)
         |> assign(:nickname_form, to_form(%{"nickname" => ""}))
         |> assign(:message_form, to_form(%{"content" => ""}))
         |> stream(:messages, [])
         |> stream(:participants, [])
         |> assign(:typing_users, %{})
         |> assign(:show_join_modal, true)}
         
      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "채팅방을 찾을 수 없습니다.")
         |> push_navigate(to: ~p"/chat")}
    end
  end

  @impl true
  def handle_info(:load_messages, socket) do
    room_id = socket.assigns.room.id
    
    # Load recent messages using our new function
    {:ok, messages} = About.Chat.Message.list_by_room(room_id)
    
    # Load participants
    participants = About.Chat.Participant
      |> Ash.Query.filter(room_id: room_id, is_online: true)
      |> Ash.Query.load(:user)
      |> Ash.read!(domain: About.Chat)
    
    {:noreply,
     socket
     |> stream(:messages, messages)
     |> stream(:participants, participants)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    system_message = %{
      id: Ash.UUID.generate(),
      content: "#{participant.nickname}님이 입장했습니다.",
      type: :system,
      inserted_at: DateTime.utc_now(),
      participant: participant
    }
    
    {:noreply,
     socket
     |> stream_insert(:participants, participant)
     |> stream_insert(:messages, system_message)}
  end

  @impl true
  def handle_info({:participant_left, participant_id}, socket) do
    {:noreply, stream_delete(socket, :participants, %{id: participant_id})}
  end

  @impl true
  def handle_info({:user_typing, %{participant_id: participant_id, nickname: nickname}}, socket) do
    current_id = socket.assigns[:current_participant] && socket.assigns.current_participant.id
    
    if participant_id != current_id do
      typing_users = Map.put(socket.assigns.typing_users, participant_id, nickname)
      Process.send_after(self(), {:stop_typing, participant_id}, 3000)
      
      {:noreply, assign(socket, :typing_users, typing_users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:stop_typing, participant_id}, socket) do
    typing_users = Map.delete(socket.assigns.typing_users, participant_id)
    {:noreply, assign(socket, :typing_users, typing_users)}
  end

  @impl true
  def handle_event("join_room", %{"participant" => %{"nickname" => nickname}}, socket) do
    IO.puts("=== JOIN_ROOM EVENT RECEIVED ===")
    IO.inspect(nickname, label: "Nickname")
    
    room_id = socket.assigns.room.id
    user_id = Map.get(socket.assigns, :current_user, %{}) |> Map.get(:id)
    
    IO.inspect(room_id, label: "Room ID")
    IO.inspect(user_id, label: "User ID")
    
    changeset = Ash.Changeset.for_create(About.Chat.Participant, :join_room, %{
      nickname: nickname,
      room_id: room_id,
      user_id: user_id
    })
    
    case Ash.create(changeset, domain: About.Chat) do
      {:ok, participant} ->
        # Broadcast join event
        PubSub.broadcast(
          About.PubSub,
          "room:#{room_id}",
          {:participant_joined, participant}
        )
        
        {:noreply,
         socket
         |> assign(:current_participant, participant)
         |> assign(:show_join_modal, false)}
         
      {:error, error} ->
        IO.puts("=== JOIN_ROOM ERROR ===")
        IO.inspect(error, label: "Error details")
        {:noreply, put_flash(socket, :error, "입장에 실패했습니다.")}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    content = String.trim(content)
    
    if content != "" && socket.assigns.current_participant do
      room_id = socket.assigns.room.id
      participant_id = socket.assigns.current_participant.id
      
      case About.Chat.Message.send(%{
        content: content,
        room_id: room_id,
        participant_id: participant_id
      }) do
        {:ok, message} ->
          message = Ash.load!(message, participant: [:user])
          
          # Broadcast message
          PubSub.broadcast(
            About.PubSub,
            "room:#{room_id}",
            {:new_message, message}
          )
          
          {:noreply, assign(socket, :message_form, to_form(%{"content" => ""}))}
          
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "메시지 전송에 실패했습니다.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("typing", _, socket) do
    if socket.assigns.current_participant do
      PubSub.broadcast(
        About.PubSub,
        "room:#{socket.assigns.room.id}",
        {:user_typing, %{
          participant_id: socket.assigns.current_participant.id,
          nickname: socket.assigns.current_participant.nickname
        }}
      )
    end
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_room", _, socket) do
    if socket.assigns.current_participant do
      participant_id = socket.assigns.current_participant.id
      About.Chat.Participant.leave_room(%{participant_id: participant_id})
      
      # Broadcast leave event
      PubSub.broadcast(
        About.PubSub,
        "room:#{socket.assigns.room.id}",
        {:participant_left, participant_id}
      )
    end
    
    {:noreply, push_navigate(socket, to: ~p"/chat")}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:current_participant] do
      participant_id = socket.assigns.current_participant.id
      About.Chat.Participant.leave_room(%{participant_id: participant_id})
      
      PubSub.broadcast(
        About.PubSub,
        "room:#{socket.assigns.room.id}",
        {:participant_left, participant_id}
      )
    end
    
    :ok
  end
end