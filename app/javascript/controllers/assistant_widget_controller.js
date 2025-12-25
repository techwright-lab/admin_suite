import { Controller } from "@hotwired/stimulus"

// Controller for the assistant widget (floating drawer).
// Handles auto-scrolling when new messages arrive.
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
    this.scrollToBottom(false)
    this.setupMutationObserver()
    
    // Also scroll when turbo stream appends content
    document.addEventListener("turbo:before-stream-render", this.handleTurboStream.bind(this))
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    document.removeEventListener("turbo:before-stream-render", this.handleTurboStream.bind(this))
  }

  // Handle turbo stream events to scroll after content is added
  handleTurboStream(event) {
    const action = event.target.getAttribute("action")
    if (action === "append" || action === "replace") {
      setTimeout(() => this.scrollToBottom(true), 50)
    }
  }

  // Scroll to the bottom of the messages container
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

  // Watch for new messages and auto-scroll
  setupMutationObserver() {
    if (!this.hasMessagesContainerTarget) return

    this.observer = new MutationObserver((mutations) => {
      let shouldScroll = false
      
      for (const mutation of mutations) {
        if (mutation.addedNodes.length > 0) {
          shouldScroll = true
          break
        }
        if (mutation.type === "attributes") {
          shouldScroll = true
          break
        }
      }
      
      if (shouldScroll) {
        this.scrollToBottom(true)
      }
    })

    // Watch the entire container for changes
    this.observer.observe(this.messagesContainerTarget, { 
      childList: true, 
      subtree: true,
      attributes: true,
      attributeFilter: ["id", "class"]
    })
  }
}
