import { Controller } from "@hotwired/stimulus"

// Utility controller for common click/change actions (Admin Suite).
export default class extends Controller {
  static values = {
    modalId: String,
    url: String,
    inputId: String,
    fallbackUrl: String,
  }

  openModal(event) {
    event.preventDefault()
    const modal = document.getElementById(this.modalIdValue)
    if (modal) {
      modal.dispatchEvent(new CustomEvent("modal:show"))
    } else if (this.hasFallbackUrlValue) {
      window.location.href = this.fallbackUrlValue
    }
  }

  closeModal(event) {
    event.preventDefault()
    const modal = document.getElementById(this.modalIdValue)
    if (modal) {
      modal.dispatchEvent(new CustomEvent("modal:hide"))
    }
  }

  hideModal(event) {
    event.preventDefault()
    const modal = document.getElementById(this.modalIdValue)
    if (modal) {
      modal.classList.add("hidden")
    }
  }

  navigate(event) {
    const clickedInteractive = event.target.closest(
      "a, button, input, select, textarea, [data-action]",
    )
    if (clickedInteractive && clickedInteractive !== this.element) {
      return
    }
    if (this.hasUrlValue) {
      window.location.href = this.urlValue
    }
  }

  redirectToValue(event) {
    const value = event.target.value
    if (value) {
      window.location.href = value
    }
  }

  clearAndSubmit(event) {
    event.preventDefault()
    const input = document.getElementById(this.inputIdValue)
    if (input) {
      input.value = ""
      const form = input.closest("form")
      if (form) {
        form.requestSubmit()
      }
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}

