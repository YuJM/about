defmodule About.Chat.MessageTest do
  use ExUnit.Case
  use About.DataCase

  alias About.Chat.Message
  alias About.Chat.Room
  alias About.Chat.Participant

  describe "메시지 전송 기능" do
    setup do
      # 테스트용 채팅방 생성
      {:ok, room} =
        Room.create(%{
          name: "테스트방",
          description: "테스트용 채팅방"
        })

      # 테스트용 참여자 생성
      {:ok, participant} =
        Participant.join_room(%{
          nickname: "테스터",
          room_id: room.id
        })

      {:ok, %{room: room, participant: participant}}
    end

    test "메시지가 성공적으로 전송되어야 한다", %{room: room, participant: participant} do
      # Given: 메시지 내용이 준비됨
      message_content = "안녕하세요! 테스트 메시지입니다."

      # When: 메시지 전송 요청
      result =
        Message.send(%{
          content: message_content,
          room_id: room.id,
          participant_id: participant.id
        })

      # Then: 메시지가 성공적으로 생성되어야 함
      assert {:ok, message} = result
      assert message.content == message_content
      assert message.room_id == room.id
      assert message.participant_id == participant.id
      assert message.type == :user
      assert is_struct(message.inserted_at, DateTime)
    end

    test "빈 메시지는 전송할 수 없다", %{room: room, participant: participant} do
      # Given: 빈 메시지 내용
      message_content = ""

      # When: 빈 메시지 전송 시도
      result =
        Message.send(%{
          content: message_content,
          room_id: room.id,
          participant_id: participant.id
        })

      # Then: 에러가 발생해야 함
      assert {:error, _changeset} = result
    end

    test "공백만 있는 메시지는 전송할 수 없다", %{room: room, participant: participant} do
      # Given: 공백만 있는 메시지 내용
      message_content = "   \n\t  "

      # When: 공백 메시지 전송 시도
      result =
        Message.send(%{
          content: message_content,
          room_id: room.id,
          participant_id: participant.id
        })

      # Then: 에러가 발생해야 함
      assert {:error, _changeset} = result
    end

    test "너무 긴 메시지는 전송할 수 없다", %{room: room, participant: participant} do
      # Given: 최대 길이를 초과하는 메시지 (1000자 초과)
      message_content = String.duplicate("a", 1001)

      # When: 긴 메시지 전송 시도
      result =
        Message.send(%{
          content: message_content,
          room_id: room.id,
          participant_id: participant.id
        })

      # Then: 에러가 발생해야 함
      assert {:error, _changeset} = result
    end

    test "존재하지 않는 채팅방에는 메시지를 보낼 수 없다", %{participant: participant} do
      # Given: 존재하지 않는 채팅방 ID
      fake_room_id = Ash.UUID.generate()

      # When: 존재하지 않는 채팅방에 메시지 전송 시도
      result =
        Message.send(%{
          content: "테스트 메시지",
          room_id: fake_room_id,
          participant_id: participant.id
        })

      # Then: 에러가 발생해야 함
      assert {:error, _changeset} = result
    end

    test "존재하지 않는 참여자는 메시지를 보낼 수 없다", %{room: room} do
      # Given: 존재하지 않는 참여자 ID
      fake_participant_id = Ash.UUID.generate()

      # When: 존재하지 않는 참여자가 메시지 전송 시도
      result =
        Message.send(%{
          content: "테스트 메시지",
          room_id: room.id,
          participant_id: fake_participant_id
        })

      # Then: 에러가 발생해야 함
      assert {:error, _changeset} = result
    end
  end

  describe "메시지 조회 기능" do
    setup do
      # 테스트용 채팅방 및 참여자 생성
      {:ok, room} =
        Room.create(%{
          name: "테스트방",
          description: "테스트용 채팅방"
        })

      {:ok, participant} =
        Participant.join_room(%{
          nickname: "테스터",
          room_id: room.id
        })

      # 테스트 메시지들 생성
      messages =
        for i <- 1..5 do
          {:ok, message} =
            Message.send(%{
              content: "테스트 메시지 #{i}",
              room_id: room.id,
              participant_id: participant.id
            })

          message
        end

      {:ok, %{room: room, participant: participant, messages: messages}}
    end

    test "채팅방의 메시지 목록을 조회할 수 있다", %{room: room, messages: messages} do
      # When: 채팅방 메시지 조회
      result = Message.list_by_room(room.id)

      # Then: 메시지 목록이 반환되어야 함
      assert {:ok, retrieved_messages} = result
      assert length(retrieved_messages) == 5

      # 메시지가 시간순으로 정렬되어 있는지 확인
      message_ids = Enum.map(retrieved_messages, & &1.id)
      expected_ids = Enum.map(messages, & &1.id)
      assert message_ids == expected_ids
    end

    test "메시지에는 작성자 정보가 포함되어야 한다", %{room: room} do
      # When: 메시지 조회 시 participant 정보 로드
      {:ok, messages} = Message.list_by_room(room.id, load: [:participant])

      # Then: 각 메시지에 작성자 정보가 포함되어야 함
      for message <- messages do
        assert %Participant{} = message.participant
        assert message.participant.nickname == "테스터"
      end
    end
  end
end
