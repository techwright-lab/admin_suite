import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ai-assistant"
export default class extends Controller {
  static targets = ["drawer", "button", "messages", "input"]

  toggle(event) {
    event.preventDefault()
    
    if (this.drawerTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.drawerTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  close() {
    this.drawerTarget.classList.add("hidden")
  }

  async ask(event) {
    event.preventDefault()
    
    const question = this.inputTarget.value.trim()
    if (!question) return

    // Add user message
    this.addMessage(question, "user")
    this.inputTarget.value = ""

    // Show loading
    const loadingId = this.addMessage("Thinking...", "assistant", true)

    try {
      // TODO: Replace with actual API call
      // For now, show a placeholder response
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      this.removeMessage(loadingId)
      this.addMessage(
        "I'm still being set up! Soon I'll be able to help you with interview insights and suggestions.",
        "assistant"
      )
    } catch (error) {
      this.removeMessage(loadingId)
      this.addMessage("Sorry, I encountered an error. Please try again.", "assistant")
    }
  }

  addMessage(text, sender, isLoading = false) {
    const messageId = `msg-${Date.now()}`
    const messageHTML = sender === "user" 
      ? this.userMessageHTML(text)
      : this.assistantMessageHTML(text, isLoading)

    const wrapper = document.createElement("div")
    wrapper.id = messageId
    wrapper.innerHTML = messageHTML
    
    this.messagesTarget.appendChild(wrapper)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    
    return messageId
  }

  removeMessage(messageId) {
    const message = document.getElementById(messageId)
    if (message) {
      message.remove()
    }
  }

  userMessageHTML(text) {
    return `
      <div class="flex items-start justify-end">
        <div class="bg-primary-500 text-white rounded-lg p-3 max-w-[80%]">
          <p class="text-sm">${this.escapeHTML(text)}</p>
        </div>
      </div>
    `
  }

  assistantMessageHTML(text, isLoading = false) {
    return `
      <div class="flex items-start">
        <div class="w-8 h-8 bg-primary-100 dark:bg-primary-900/30 rounded-full flex items-center justify-center mr-3 flex-shrink-0">
          <svg class="w-4 h-4 text-primary-600 dark:text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
        </div>
        <div class="flex-1 bg-gray-100 dark:bg-dark-800 rounded-lg p-3">
          <p class="text-sm text-gray-900 dark:text-white ${isLoading ? 'animate-pulse' : ''}">
            ${this.escapeHTML(text)}
          </p>
        </div>
      </div>
    `
  }

  escapeHTML(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

