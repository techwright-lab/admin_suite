import { Controller } from "@hotwired/stimulus"

// Assistant composer controller with keyboard support and auto-resize.
//
// Scroll behavior (ChatGPT-style):
// - After user's message is added to DOM, scroll it to the TOP of the view
// - This leaves maximum space below for the assistant's response
// - Response fills in below without interrupting the user's view
// - Requires a large spacer (60vh+) at the bottom of messages container
//
// Features:
// - Enter to submit, Shift+Enter for new line
// - Auto-resize textarea as content grows
// - Request idempotency with client_request_uuid
// - Disable during submission
//
// Example:
// <form data-controller="assistant-composer">
//   <input type="hidden" name="client_request_uuid" data-assistant-composer-target="requestId" />
//   <textarea data-assistant-composer-target="input" data-action="keydown->assistant-composer#handleKeydown input->assistant-composer#autoResize"></textarea>
//   <button data-assistant-composer-target="submitButton">Send</button>
// </form>
export default class extends Controller {
  static targets = ["requestId", "input", "submitButton"]

  connect() {
    this.generateRequestId()
    this.autoResize()
  }

  // Handle form submission start
  submitStart() {
    this.generateRequestId()
    this.disableForm()
  }

  // Handle form submission end - Turbo has processed the response and updated DOM
  submitEnd() {
    this.enableForm()
    this.clearInput()
    this.generateRequestId()
    
    // Small delay to ensure DOM is fully updated after Turbo Stream processing
    requestAnimationFrame(() => {
      setTimeout(() => this.scrollUserMessageToTop(), 100)
    })
  }

  // Scroll the last user message to the top of the scrollable container (ChatGPT-style)
  scrollUserMessageToTop() {
    // Find the scrollable container
    const container = document.querySelector("[data-assistant-chat-target='messagesContainer']") ||
                      document.querySelector("[data-assistant-widget-target='messagesContainer']")
    
    if (!container) return

    // Find all user messages anywhere in the container
    const userMessages = container.querySelectorAll("[data-role='user']")
    if (userMessages.length === 0) return
    
    const lastUserMessage = userMessages[userMessages.length - 1]

    // Calculate the message's offsetTop by walking up the offsetParent chain
    let offsetTop = 0
    let element = lastUserMessage
    
    while (element && element !== container && element !== document.body) {
      offsetTop += element.offsetTop
      element = element.offsetParent
    }
    
    // Scroll to put the message at the top (with 16px padding)
    const targetScroll = Math.max(0, offsetTop - 16)
    
    container.scrollTo({
      top: targetScroll,
      behavior: "smooth"
    })
  }

  // Handle keyboard events
  handleKeydown(event) {
    // Enter without Shift submits the form
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      
      // Only submit if there's content
      if (this.hasInputTarget && this.inputTarget.value.trim()) {
        this.element.requestSubmit()
      }
      return
    }

    // Escape blurs the input
    if (event.key === "Escape") {
      event.preventDefault()
      if (this.hasInputTarget) {
        this.inputTarget.blur()
      }
    }
  }

  // Auto-resize textarea based on content
  autoResize() {
    if (!this.hasInputTarget) return

    const textarea = this.inputTarget
    
    // Reset height to auto to get the correct scrollHeight
    textarea.style.height = "auto"
    
    // Set new height based on content, with max height limit
    const newHeight = Math.min(textarea.scrollHeight, 128) // max-h-32 = 128px
    textarea.style.height = `${newHeight}px`
  }

  // Clear input and reset height
  clearInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.style.height = "auto"
      this.inputTarget.focus()
    }
  }

  // Disable form during submission
  disableForm() {
    if (this.hasInputTarget) {
      this.inputTarget.disabled = true
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  // Enable form after submission
  enableForm() {
    if (this.hasInputTarget) {
      this.inputTarget.disabled = false
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
  }

  // Generate a new request ID for idempotency
  generateRequestId() {
    if (this.hasRequestIdTarget) {
      this.requestIdTarget.value = this.generateUuid()
    }
  }

  generateUuid() {
    // Prefer Web Crypto UUIDs when available.
    if (window.crypto?.randomUUID) return window.crypto.randomUUID()

    // Fallback UUID v4 generator.
    const bytes = window.crypto?.getRandomValues ? window.crypto.getRandomValues(new Uint8Array(16)) : null
    if (!bytes) return `${Date.now()}-${Math.random()}`

    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80

    const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("")
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  }
}
