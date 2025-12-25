import { Controller } from "@hotwired/stimulus"

// Controller for the assistant chat page.
// Handles auto-scrolling, keyboard shortcuts, and prompt suggestions.
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
    // Initial scroll to bottom
    this.scrollToBottom(false)
    this.setupMutationObserver()
    this.setupKeyboardShortcuts()
    
    // Also scroll when turbo stream appends content
    document.addEventListener("turbo:before-stream-render", this.handleTurboStream.bind(this))
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    document.removeEventListener("keydown", this.handleGlobalKeydown)
    document.removeEventListener("turbo:before-stream-render", this.handleTurboStream.bind(this))
  }

  // Handle turbo stream events to scroll after content is added
  handleTurboStream(event) {
    const action = event.target.getAttribute("action")
    if (action === "append" || action === "replace") {
      // Use setTimeout to ensure DOM is updated
      setTimeout(() => this.scrollToBottom(true), 50)
    }
  }

  // Scroll to the bottom of the messages container
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

  // Watch for new messages and auto-scroll
  setupMutationObserver() {
    if (!this.hasMessagesContainerTarget) return

    this.observer = new MutationObserver((mutations) => {
      let shouldScroll = false
      
      for (const mutation of mutations) {
        // Check if nodes were added
        if (mutation.addedNodes.length > 0) {
          shouldScroll = true
          break
        }
        // Also check for attribute changes (like replacing content)
        if (mutation.type === "attributes") {
          shouldScroll = true
          break
        }
      }
      
      if (shouldScroll) {
        this.scrollToBottom(true)
      }
    })

    // Watch the entire container for changes, including subtree
    this.observer.observe(this.messagesContainerTarget, { 
      childList: true, 
      subtree: true,
      attributes: true,
      attributeFilter: ["id", "class"]
    })
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
