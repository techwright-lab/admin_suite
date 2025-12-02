import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
// Usage:
// <div id="my-modal" data-controller="modal" class="hidden">
//   <div data-modal-target="content">Modal content</div>
// </div>
// <button onclick="document.getElementById('my-modal').dispatchEvent(new CustomEvent('modal:show'))">Open</button>
export default class extends Controller {
  static targets = ["content"]

  connect() {
    // Listen for custom events to show/hide modal
    this.element.addEventListener('modal:show', () => this.show())
    this.element.addEventListener('modal:hide', () => this.hide())
  }

  disconnect() {
    this.element.removeEventListener('modal:show', () => this.show())
    this.element.removeEventListener('modal:hide', () => this.hide())
  }

  show(event) {
    if (event) {
      event.preventDefault?.()
    }
    
    this.element.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Trap focus within modal
    this.element.focus()
  }

  hide(event) {
    if (event) {
      event.preventDefault()
    }
    
    this.element.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  closeWithKeyboard(event) {
    if (event.code === "Escape") {
      this.hide()
    }
  }

  closeBackground(event) {
    // Only close if clicking the backdrop, not the content
    if (event.target === this.element) {
      this.hide()
    }
  }
}
