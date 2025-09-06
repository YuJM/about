// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/about"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// 채팅방 세션 관리를 위한 Hook
const ChatRoomHooks = {
  ChatRoom: {
    mounted() {
      // 저장된 참여자 정보 로드
      const roomId = this.el.dataset.roomId
      const storedParticipantId = sessionStorage.getItem(`participant_${roomId}`)
      
      if (storedParticipantId) {
        this.pushEvent("restore_participant", {
          room_id: roomId,
          participant_id: storedParticipantId
        })
      }
      
      // 참여자 정보 저장 이벤트 리스너
      this.handleEvent("save_participant", ({room_id, participant_id}) => {
        sessionStorage.setItem(`participant_${room_id}`, participant_id)
      })
      
      // 참여자 정보 삭제 이벤트 리스너
      this.handleEvent("clear_participant", ({room_id}) => {
        sessionStorage.removeItem(`participant_${room_id}`)
      })
      
      // 닉네임 변경 시 세션 업데이트
      this.handleEvent("update_session_nickname", ({nickname, session_id}) => {
        // Ajax 요청으로 서버 세션 업데이트
        fetch('/chat/set_nickname?' + new URLSearchParams({
          nickname: nickname,
          session_id: session_id
        }), {
          method: 'GET',
          headers: {
            'X-CSRF-Token': document.querySelector("meta[name='csrf-token']").getAttribute("content")
          }
        }).then(() => {
          // 로컬 스토리지도 업데이트
          sessionStorage.setItem('chat_nickname', nickname)
        })
      })
      
      // 뒤로가기/앞으로가기 감지 (popstate)
      const handlePopState = () => {
        this.pushEvent("leave_room", {})
      }
      
      // LiveView 페이지 네비게이션 감지
      const handlePageLoading = () => {
        this.pushEvent("leave_room", {})
      }
      
      // 브라우저 종료 감지
      const handleBeforeUnload = () => {
        this.pushEvent("leave_room", {})
      }
      
      // 이벤트 리스너 등록
      window.addEventListener("popstate", handlePopState)
      window.addEventListener("beforeunload", handleBeforeUnload)
      this.handleEvent("phx:page-loading-start", handlePageLoading)
      
      // cleanup 함수 저장
      this._cleanup = () => {
        window.removeEventListener("popstate", handlePopState)
        window.removeEventListener("beforeunload", handleBeforeUnload)
      }
    },
    
    destroyed() {
      // 이벤트 리스너 정리
      if (this._cleanup) {
        this._cleanup()
      }
    }
  },
  
  ChatNickname: {
    mounted() {
      // 세션 ID 생성 또는 가져오기
      let sessionId = sessionStorage.getItem('chat_session_id')
      if (!sessionId) {
        sessionId = crypto.randomUUID ? crypto.randomUUID() : 
                   'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                     const r = Math.random() * 16 | 0
                     const v = c == 'x' ? r : (r & 0x3 | 0x8)
                     return v.toString(16)
                   })
        sessionStorage.setItem('chat_session_id', sessionId)
      }
      
      // 세션 ID를 서버에 전송
      this.pushEvent("set_session_id", {session_id: sessionId})
      
      // 닉네임 저장 이벤트 리스너
      this.handleEvent("save_nickname", ({nickname}) => {
        sessionStorage.setItem('chat_nickname', nickname)
      })
      
      // 닉네임 삭제 이벤트 리스너
      this.handleEvent("clear_nickname", () => {
        sessionStorage.removeItem('chat_nickname')
      })
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...ChatRoomHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

