import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="admin-suite--flash"
export default class extends Controller {
  static targets = ["notification"]

  connect() {
    this.timeout = setTimeout(() => this.dismissAll(), 5000)
  }

  dismiss(event) {
    if (event) {
      event.preventDefault()
    }

    const notification = event?.currentTarget?.closest('[data-admin-suite--flash-target="notification"]')
    if (notification) {
      this.fadeOut(notification)
    }
  }

  dismissAll() {
    this.notificationTargets.forEach((notification) => this.fadeOut(notification))
  }

  fadeOut(element) {
    if (!element || !element.isConnected) return

    element.style.transition = "opacity 0.25s ease-out, transform 0.25s ease-out"
    element.style.opacity = "0"
    element.style.transform = "translateX(8px)"

    setTimeout(() => {
      if (element.isConnected) {
        element.remove()
      }
    }, 250)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}
