import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="autocomplete-modal"
export default class extends Controller {
  static targets = ["form", "errors"]
  static values = {
    createUrl: String
  }

  connect() {
    // Bind to modal controller if it exists
    this.modalController = this.application.getControllerForElementAndIdentifier(
      this.element,
      "modal"
    )
  }

  async submit(event) {
    event.preventDefault()
    
    const form = event.target
    const formData = new FormData(form)
    
    // Clear previous errors
    this.clearErrors()
    
    // Show loading state
    const submitButton = form.querySelector('button[type="submit"]')
    const originalText = submitButton.textContent
    submitButton.disabled = true
    submitButton.textContent = "Creating..."
    
    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: formData
      })
      
      const data = await response.json()
      
      if (response.ok) {
        this.handleSuccess(data)
      } else {
        this.handleErrors(data)
      }
    } catch (error) {
      console.error("Creation error:", error)
      this.showError("Failed to create. Please try again.")
    } finally {
      // Restore button state
      submitButton.disabled = false
      submitButton.textContent = originalText
    }
  }

  handleSuccess(data) {
    // Get the autocomplete element ID from modal dataset
    const autocompleteId = this.element.dataset.autocompleteElement
    
    // Dispatch event to notify autocomplete controller
    document.dispatchEvent(new CustomEvent("autocomplete:created", {
      detail: {
        id: data.id,
        name: data.name || data.title,
        autocompleteId: autocompleteId
      }
    }))
    
    // Close modal
    this.close()
    
    // Show success flash message
    this.showFlash("Created successfully!", "success")
  }

  handleErrors(data) {
    if (data.errors) {
      // Display validation errors
      const errorMessages = Object.entries(data.errors)
        .map(([field, messages]) => {
          const fieldName = field.charAt(0).toUpperCase() + field.slice(1)
          return `${fieldName}: ${Array.isArray(messages) ? messages.join(", ") : messages}`
        })
        .join("<br>")
      
      this.showError(errorMessages)
    } else {
      this.showError("Validation failed. Please check your input.")
    }
  }

  showError(message) {
    if (this.hasErrorsTarget) {
      this.errorsTarget.innerHTML = `
        <div class="rounded-md bg-red-50 dark:bg-red-900/20 p-4 mb-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
              </svg>
            </div>
            <div class="ml-3">
              <p class="text-sm text-red-800 dark:text-red-200">${message}</p>
            </div>
          </div>
        </div>
      `
      this.errorsTarget.classList.remove("hidden")
    } else {
      // Fallback: show alert
      alert(message)
    }
  }

  clearErrors() {
    if (this.hasErrorsTarget) {
      this.errorsTarget.innerHTML = ""
      this.errorsTarget.classList.add("hidden")
    }
  }

  close() {
    // Clear form
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
    
    // Clear errors
    this.clearErrors()
    
    // Close modal using modal controller if available
    if (this.modalController) {
      this.modalController.hide()
    } else {
      // Fallback: manually hide modal
      this.element.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  showFlash(message, type = "notice") {
    // Dispatch event for flash controller
    document.dispatchEvent(new CustomEvent("flash:show", {
      detail: { message, type }
    }))
  }

  get csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ""
  }
}

