/*(function() {

  let nickname
  let socket

  document.getElementById("set-nickname").onclick = () => {
    let nick = document.getElementById("nickname").value
    if(nick.length > 0) {
      nickname = nick
      socket = new WebSocket("ws://" + window.location.hostname + ":3001")
      socket.onopen = event => socket.send("NICK " + nickname)
      socket.onmessage = event => {
        let textarea = document.getElementById("messages")
        textarea.value = textarea.value + "\n" + event.data
      }
    }
  }

  document.getElementById("send-message").onclick = () => {
    
  }

})()*/

(function() {
  if(!window.WebSocket) return
  socket = new WebSocket("ws://localhost:3001")
  socket.onopen = e => console.log("WebSocket is open")
  socket.onclose = e => console.log("WebSocket is closed")
  socket.onerror = e => console.log("WebSocket error occurred")
  socket.onmessage = e => console.log("WebSocket MESSAGE: " + e.data)
})()