import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static targets = ["notification"]

  connect() {
    // Auto-dismiss after 5 seconds
    this.timeout = setTimeout(() => {
      this.dismissAll()
    }, 5000)
  }

  dismiss(event) {
    const notification = event.currentTarget.closest('[data-flash-target="notification"]')
    this.fadeOut(notification)
  }

  dismissAll() {
    this.notificationTargets.forEach(notification => {
      this.fadeOut(notification)
    })
  }

  fadeOut(element) {
    element.style.transition = "opacity 0.3s ease-out"
    element.style.opacity = "0"
    
    setTimeout(() => {
      element.remove()
    }, 300)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

