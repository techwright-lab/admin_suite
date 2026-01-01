import { Controller } from "@hotwired/stimulus"

// Controller for the assistant chat page (full page view).
//
// Only scrolls to bottom on:
// - Initial load (to show latest messages)
// - User submitting a new message (handled by composer controller)
//
// Does NOT auto-scroll when assistant responses arrive, so users can read
// previous content without being interrupted.
//
// Example:
// <div data-controller="assistant-chat" data-assistant-chat-thread-id-value="123">
//   <div data-assistant-chat-target="messagesContainer">...</div>
// </div>
export default class extends Controller {
  static targets = ["messagesContainer", "input"]
  static values = {
    threadId: Number
  }

  connect() {
    // Initial scroll to bottom (instant, no animation)
    this.scrollToBottom(false)
    this.setupKeyboardShortcuts()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleGlobalKeydown)
  }

  // Scroll to the bottom of the messages container
  // Called by composer controller after user submits a message
  // @param smooth - whether to use smooth scrolling
  scrollToBottom(smooth = true) {
    if (this.hasMessagesContainerTarget) {
      const container = this.messagesContainerTarget
      
      // Use requestAnimationFrame to ensure layout is complete
      requestAnimationFrame(() => {
        if (smooth) {
          container.scrollTo({
            top: container.scrollHeight,
            behavior: "smooth"
          })
        } else {
          container.scrollTop = container.scrollHeight
        }
      })
    }
  }

  // Setup global keyboard shortcuts
  setupKeyboardShortcuts() {
    this.handleGlobalKeydown = (event) => {
      // Cmd/Ctrl + K to focus input
      if ((event.metaKey || event.ctrlKey) && event.key === "k") {
        event.preventDefault()
        const input = document.querySelector("[data-assistant-composer-target='input']")
        if (input) {
          input.focus()
        }
      }
    }
    
    document.addEventListener("keydown", this.handleGlobalKeydown)
  }

  // Insert a suggested prompt into the input field
  insertPrompt(event) {
    const prompt = event.currentTarget.dataset.prompt
    if (!prompt) return

    const input = document.querySelector("[data-assistant-composer-target='input']")
    if (input) {
      input.value = prompt
      input.focus()
      // Trigger input event to resize textarea
      input.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }
}
