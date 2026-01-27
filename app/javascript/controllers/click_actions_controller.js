import { Controller } from "@hotwired/stimulus"

// Utility controller for common click/change actions without inline handlers
// This helps comply with Content Security Policy (CSP) by avoiding inline JS
//
// Usage examples:
//
// Open a modal:
// <button data-controller="click-actions" data-action="click->click-actions#openModal" data-click-actions-modal-id-value="my-modal">Open</button>
//
// Close a modal:
// <button data-controller="click-actions" data-action="click->click-actions#closeModal" data-click-actions-modal-id-value="my-modal">Close</button>
//
// Navigate to URL:
// <tr data-controller="click-actions" data-action="click->click-actions#navigate" data-click-actions-url-value="/path">...</tr>
//
// Redirect on select change:
// <select data-controller="click-actions" data-action="change->click-actions#redirectToValue">
//   <option value="/path1">Option 1</option>
// </select>
//
// Clear input and submit form:
// <button data-controller="click-actions" data-action="click->click-actions#clearAndSubmit" data-click-actions-input-id-value="search-input">Clear</button>
//
// Stop event propagation (for nested clickables):
// <button data-controller="click-actions" data-action="click->click-actions#stopPropagation">...</button>

export default class extends Controller {
  static values = {
    modalId: String,
    url: String,
    inputId: String,
    fallbackUrl: String
  }

  // Opens a modal by dispatching 'modal:show' event
  openModal(event) {
    event.preventDefault()
    const modal = document.getElementById(this.modalIdValue)
    if (modal) {
      modal.dispatchEvent(new CustomEvent('modal:show'))
    } else if (this.hasFallbackUrlValue) {
      window.location.href = this.fallbackUrlValue
    }
  }

  // Closes a modal by dispatching 'modal:hide' event
  closeModal(event) {
    event.preventDefault()
    const modal = document.getElementById(this.modalIdValue)
    if (modal) {
      modal.dispatchEvent(new CustomEvent('modal:hide'))
    }
  }

  // Hides a modal by adding 'hidden' class (for simple modals without controller)
  hideModal(event) {
    event.preventDefault()
    const modal = document.getElementById(this.modalIdValue)
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  // Navigates to the URL specified in data-click-actions-url-value
  navigate(event) {
    // Don't navigate if clicking on interactive elements inside (excluding the controller element itself)
    const clickedInteractive = event.target.closest('a, button, input, select, textarea, [data-action]')
    if (clickedInteractive && clickedInteractive !== this.element) {
      return
    }
    if (this.hasUrlValue) {
      window.location.href = this.urlValue
    }
  }

  // Redirects to the selected option's value (for select elements)
  redirectToValue(event) {
    const value = event.target.value
    if (value) {
      window.location.href = value
    }
  }

  // Clears an input field and submits the closest form
  clearAndSubmit(event) {
    event.preventDefault()
    const input = document.getElementById(this.inputIdValue)
    if (input) {
      input.value = ''
      const form = input.closest('form')
      if (form) {
        form.requestSubmit()
      }
    }
  }

  // Stops event propagation (useful for nested clickable elements)
  stopPropagation(event) {
    event.stopPropagation()
  }
}
