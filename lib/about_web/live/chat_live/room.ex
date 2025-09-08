defmodule AboutWeb.ChatLive.Room do
  use AboutWeb, :live_view

  require Ash.Query

  alias Phoenix.PubSub
  alias AboutWeb.ChatPresence

  @impl true
  def mount(%{"id" => room_id}, session, socket) do
    case Ash.get(About.Chat.Room, room_id, domain: About.Chat) do
      {:ok, room} ->
        # 세션에서 닉네임과 세션 ID 확인 - 중앙집중식 관리
        nickname = Map.get(session, "chat_nickname")
        session_id = Map.get(session, "chat_session_id")
        participant_id = Map.get(session, "participant_#{room_id}")

        # 닉네임이 없으면 /chat로 리다이렉트
        if is_nil(nickname) do
          {:ok,
           socket
           |> put_flash(:info, "먼저 닉네임을 설정해주세요.")
           |> push_navigate(to: ~p"/chat")}
        else
          socket =
            socket
            |> assign(:page_title, room.name)
            |> assign(:room, room)
            |> assign(:nickname, nickname)
            |> assign(:session_id, session_id)
            |> assign(:message_form, to_form(%{"content" => ""}))
            |> stream(:messages, [])
            |> stream(:participants, [], dom_id: & &1.stream_id)
            |> assign(:typing_users, %{})

          # 참여자 처리 - DB 참여 기록은 유지하되, 온라인 상태는 순수 Presence
          socket =
            if participant_id do
              case Ash.get(About.Chat.Participant, participant_id, domain: About.Chat) do
                {:ok, participant} ->
                  # 기존 참여자 재입장: 연결 완료 후 Presence 추적 시작
                  socket = socket |> assign(:current_participant, participant)

                  if connected?(socket) do
                    PubSub.subscribe(About.PubSub, "room:#{room_id}")
                    send(self(), :after_join)
                  end

                  socket

                {:error, _} ->
                  # 참여자를 찾을 수 없으면 새로 생성
                  create_new_participant(socket, room_id, nickname)
              end
            else
              # 세션에 참여자 정보가 없으면 새로 생성
              create_new_participant(socket, room_id, nickname)
            end

          {:ok, socket}
        end

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "채팅방을 찾을 수 없습니다.")
         |> push_navigate(to: ~p"/chat")}
    end
  end

  # 새 참여자 생성 또는 기존 참여자 재사용
  defp create_new_participant(socket, room_id, nickname) do
    user_id = Map.get(socket.assigns, :current_user, %{}) |> Map.get(:id)

    # 먼저 기존 참여자 확인 (닉네임 + 방 기준)
    existing_participants =
      About.Chat.Participant
      |> Ash.Query.filter(room_id == ^room_id and nickname == ^nickname)
      |> Ash.read!(domain: About.Chat)

    participant =
      case existing_participants do
        [existing | _] ->
          # 기존 참여자 재사용
          existing

        [] ->
          # 새 참여자 생성
          changeset =
            Ash.Changeset.for_create(About.Chat.Participant, :join_room, %{
              nickname: nickname,
              room_id: room_id,
              user_id: user_id
            })

          case Ash.create(changeset, domain: About.Chat) do
            {:ok, new_participant} -> new_participant
            {:error, _} -> nil
          end
      end

    if participant do
      socket = socket |> assign(:current_participant, participant)

      if connected?(socket) do
        PubSub.subscribe(About.PubSub, "room:#{room_id}")
        send(self(), :after_join)

        # 세션에 participant_id 저장
        send(self(), {:update_session, "participant_#{room_id}", participant.id})
      end

      socket
    else
      socket
      |> put_flash(:error, "채팅방 입장에 실패했습니다.")
      |> push_navigate(to: ~p"/chat")
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    if socket.assigns.current_participant && socket.assigns.session_id do
      participant = socket.assigns.current_participant
      room_id = socket.assigns.room.id
      session_id = socket.assigns.session_id

      # 세션 ID를 키로 사용하여 Presence 추적 (중복 방지)
      ChatPresence.track_participant(room_id, session_id, %{
        id: participant.id,
        nickname: participant.nickname,
        color: participant.color,
        session_id: session_id,
        participant: participant
      })

      # 참여자 입장 브로드캐스트
      PubSub.broadcast(
        About.PubSub,
        "room:#{room_id}",
        {:participant_joined, %{participant: participant, session_id: session_id}}
      )

      # 데이터 로드
      send(self(), :load_data)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_session, _key, value}, socket) do
    # 세션은 LiveView에서 직접 업데이트할 수 없으므로 이벤트로 클라이언트에 전달
    {:noreply,
     push_event(socket, "save_participant", %{
       room_id: socket.assigns.room.id,
       participant_id: value
     })}
  end

  @impl true
  def handle_info(:load_data, socket) do
    room_id = socket.assigns.room.id

    # 메시지 로드
    {:ok, messages} = About.Chat.Message.list_by_room(room_id)

    # 온라인 참여자는 Presence에서만 가져오기 (닉네임 기준)
    online_participants =
      ChatPresence.list_participants_with_meta(room_id)
      |> Enum.map(fn p -> Map.put(p, :stream_id, p.id) end)

    {:noreply,
     socket
     |> stream(:messages, messages)
     |> stream(:participants, online_participants, dom_id: & &1.stream_id)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_info(
        {:participant_joined, %{participant: participant, session_id: session_id}},
        socket
      ) do
    system_message = %{
      id: Ash.UUID.generate(),
      content: "#{participant.nickname}님이 입장했습니다.",
      type: :system,
      inserted_at: DateTime.utc_now(),
      participant: participant
    }

    # 세션 ID 기준으로 stream 관리 (중복 방지)
    online_participant = %{
      id: session_id,
      stream_id: session_id,
      nickname: participant.nickname,
      color: participant.color,
      session_id: session_id,
      participant: participant
    }

    {:noreply,
     socket
     |> stream_insert(:participants, online_participant, dom_id: session_id)
     |> stream_insert(:messages, system_message)}
  end

  @impl true
  def handle_info(
        {:participant_left,
         %{participant_id: _participant_id, nickname: nickname, session_id: session_id}},
        socket
      ) do
    system_message = %{
      id: Ash.UUID.generate(),
      content: "#{nickname}님이 퇴장했습니다.",
      type: :system,
      inserted_at: DateTime.utc_now(),
      participant: %{nickname: "시스템"}
    }

    {:noreply,
     socket
     |> stream_delete_by_dom_id(:participants, session_id)
     |> stream_insert(:messages, system_message)}
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
  def handle_info({:presence_join, session_id, meta}, socket) do
    # Presence 기반 참여자 입장 처리 (세션 ID 키)
    if meta[:participant] do
      online_participant = %{
        id: session_id,
        stream_id: session_id,
        nickname: meta.nickname,
        color: meta.color,
        session_id: session_id,
        participant: meta.participant
      }

      {:noreply, stream_insert(socket, :participants, online_participant, dom_id: session_id)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:presence_leave, session_id, meta}, socket) do
    # Presence 기반 참여자 퇴장 처리 (세션 ID 키)
    if meta[:participant] do
      participant = meta.participant

      # 퇴장 브로드캐스트
      PubSub.broadcast(
        About.PubSub,
        "room:#{socket.assigns.room.id}",
        {:participant_left,
         %{participant_id: participant.id, nickname: meta.nickname, session_id: session_id}}
      )
    end

    {:noreply, socket}
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
        {:user_typing,
         %{
           participant_id: socket.assigns.current_participant.id,
           nickname: socket.assigns.current_participant.nickname
         }}
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_room", _, socket) do
    if socket.assigns.current_participant && socket.assigns.session_id do
      participant = socket.assigns.current_participant
      participant_id = participant.id
      room_id = socket.assigns.room.id
      session_id = socket.assigns.session_id

      # 세션 ID 기준으로 정리 (뒤로가기 등에서 LiveView가 연결된 상태로 이동할 때)
      ChatPresence.untrack_participant(room_id, session_id)

      PubSub.broadcast(
        About.PubSub,
        "room:#{room_id}",
        {:participant_left,
         %{participant_id: participant_id, nickname: participant.nickname, session_id: session_id}}
      )

      # 세션 정보 삭제
      socket = push_event(socket, "clear_participant", %{room_id: room_id})

      {:noreply, push_navigate(socket, to: ~p"/chat")}
    else
      {:noreply, push_navigate(socket, to: ~p"/chat")}
    end
  end

  @impl true
  def handle_event("change_nickname", %{"nickname" => new_nickname}, socket) do
    if socket.assigns.current_participant && socket.assigns.session_id &&
         String.trim(new_nickname) != "" do
      participant = socket.assigns.current_participant
      room_id = socket.assigns.room.id
      session_id = socket.assigns.session_id
      old_nickname = participant.nickname

      # 먼저 기존 Presence 제거 (세션 ID 기준)
      ChatPresence.untrack_participant(room_id, session_id)

      case participant
           |> Ash.Changeset.for_update(:change_nickname, %{nickname: String.trim(new_nickname)})
           |> Ash.update(domain: About.Chat) do
        {:ok, updated_participant} ->
          # 세션 ID로 Presence 추적 (닉네임은 메타데이터)
          ChatPresence.track_participant(room_id, session_id, %{
            id: updated_participant.id,
            nickname: updated_participant.nickname,
            color: updated_participant.color,
            session_id: session_id,
            participant: updated_participant
          })

          # 닉네임 변경 브로드캐스트
          PubSub.broadcast(
            About.PubSub,
            "room:#{room_id}",
            {:nickname_changed,
             %{
               participant_id: participant.id,
               old_nickname: old_nickname,
               new_nickname: updated_participant.nickname,
               session_id: session_id
             }}
          )

          # 서버 세션 업데이트를 위해 컨트롤러로 리다이렉트
          {:noreply,
           socket
           |> assign(:current_participant, updated_participant)
           |> assign(:nickname, updated_participant.nickname)
           |> push_event("update_session_nickname", %{
             nickname: updated_participant.nickname,
             session_id: session_id
           })}

        {:error, _} ->
          # 실패 시 기존 닉네임으로 다시 추적 (세션 ID 기준)
          ChatPresence.track_participant(room_id, session_id, %{
            id: participant.id,
            nickname: old_nickname,
            color: participant.color,
            session_id: session_id,
            participant: participant
          })

          {:noreply, put_flash(socket, :error, "닉네임 변경에 실패했습니다.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "restore_participant",
        %{"room_id" => room_id, "participant_id" => participant_id},
        socket
      ) do
    # 세션에서 기존 참여자 정보 복원
    case Ash.get(About.Chat.Participant, participant_id, domain: About.Chat) do
      {:ok, participant} ->
        session_id = socket.assigns.session_id

        if session_id do
          # 세션 ID 기준으로 Presence 추적 시작
          ChatPresence.track_participant(room_id, session_id, %{
            id: participant.id,
            nickname: participant.nickname,
            color: participant.color,
            session_id: session_id,
            participant: participant
          })

          # 참여자 입장 브로드캐스트
          PubSub.broadcast(
            About.PubSub,
            "room:#{room_id}",
            {:participant_joined, %{participant: participant, session_id: session_id}}
          )

          {:noreply, assign(socket, :current_participant, participant)}
        else
          {:noreply, put_flash(socket, :error, "세션 ID를 찾을 수 없습니다.")}
        end

      {:error, _} ->
        # 참여자를 찾을 수 없는 경우
        {:noreply, put_flash(socket, :error, "참여자 정보를 찾을 수 없습니다.")}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    # URL 이동이나 페이지 종료 시에도 자동으로 퇴장 처리
    if socket.assigns[:current_participant] && socket.assigns[:room] &&
         socket.assigns[:session_id] do
      participant = socket.assigns.current_participant
      room_id = socket.assigns.room.id
      session_id = socket.assigns.session_id

      # 세션 ID 기준으로 Presence에서 제거 (중복 방지)
      if ChatPresence.participant_online?(room_id, session_id) do
        ChatPresence.untrack_participant(room_id, session_id)

        # 퇴장 브로드캐스트
        PubSub.broadcast(
          About.PubSub,
          "room:#{room_id}",
          {:participant_left,
           %{
             participant_id: participant.id,
             nickname: participant.nickname,
             session_id: session_id
           }}
        )
      end
    end

    :ok
  end
end
