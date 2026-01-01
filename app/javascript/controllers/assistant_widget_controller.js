import { Controller } from "@hotwired/stimulus"

// Controller for the assistant widget (side panel and main chat).
//
// Only scrolls to bottom on:
// - Initial load (to show latest messages)
// - User submitting a new message (handled by composer controller)
//
// Does NOT auto-scroll when assistant responses arrive, so users can read
// previous content without being interrupted.
//
// Example:
// <div data-controller="assistant-widget" data-assistant-widget-thread-id-value="123">
//   <div data-assistant-widget-target="messagesContainer">...</div>
// </div>
export default class extends Controller {
  static targets = ["messagesContainer"]
  static values = {
    threadId: Number
  }

  connect() {
    // Scroll to bottom on initial load only (no animation for instant positioning)
    this.scrollToBottom(false)
  }

  disconnect() {
    // No cleanup needed since we removed observers
  }

  // Scroll to the bottom of the messages container
  // Called by composer controller after user submits a message
  scrollToBottom(smooth = true) {
    if (this.hasMessagesContainerTarget) {
      const container = this.messagesContainerTarget
      
      // Force layout calculation
      container.offsetHeight
      
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
}
