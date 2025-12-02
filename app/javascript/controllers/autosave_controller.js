// Autosave controller for automatically saving form data on input changes
// Shows save status indicators and debounces saves to prevent excessive requests
//
// Example usage:
// <form data-controller="autosave" data-autosave-delay-value="1000">
//   <input data-action="input->autosave#save">
//   <span data-autosave-target="status"></span>
// </form>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "form"]
  static values = {
    delay: { type: Number, default: 1500 },
    url: String,
    method: { type: String, default: "PATCH" }
  }

  connect() {
    this.timeout = null
    this.saving = false
    this.pendingSave = false
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Triggered on input change, debounces the save
  save(event) {
    // Clear existing timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Show "typing" indicator
    this.showStatus("typing")

    // Set new timeout for debounced save
    this.timeout = setTimeout(() => {
      this.performSave()
    }, this.delayValue)
  }

  // Performs the actual save operation
  async performSave() {
    // If already saving, mark as pending
    if (this.saving) {
      this.pendingSave = true
      return
    }

    this.saving = true
    this.showStatus("saving")

    const form = this.hasFormTarget ? this.formTarget : this.element
    const formData = new FormData(form)
    const url = this.urlValue || form.action

    try {
      const response = await fetch(url, {
        method: this.methodValue,
        body: formData,
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin",
        redirect: "manual" // Prevent following redirects
      })

      // Handle successful response (200 OK) or redirect (302) which means save succeeded
      if (response.ok || response.type === "opaqueredirect" || response.status === 302) {
        this.showStatus("saved")
        // Dispatch custom event for other components to react
        this.dispatch("saved", { detail: { response } })
      } else if (response.status === 0 && response.type === "opaqueredirect") {
        // Manual redirect mode returns status 0 for redirects - this is still success
        this.showStatus("saved")
        this.dispatch("saved", { detail: { response } })
      } else {
        this.showStatus("error")
        console.error("Autosave failed:", response.statusText)
      }
    } catch (error) {
      this.showStatus("error")
      console.error("Autosave error:", error)
    } finally {
      this.saving = false

      // If there was a pending save, perform it now
      if (this.pendingSave) {
        this.pendingSave = false
        this.performSave()
      }
    }
  }

  // Shows the current status in the status target
  showStatus(status) {
    if (!this.hasStatusTarget) return

    const statusElement = this.statusTarget
    
    // Clear previous classes
    statusElement.classList.remove("text-gray-400", "text-yellow-500", "text-green-500", "text-red-500")
    
    switch (status) {
      case "typing":
        statusElement.innerHTML = this.typingHtml
        statusElement.classList.add("text-gray-400")
        break
      case "saving":
        statusElement.innerHTML = this.savingHtml
        statusElement.classList.add("text-yellow-500")
        break
      case "saved":
        statusElement.innerHTML = this.savedHtml
        statusElement.classList.add("text-green-500")
        // Clear status after 3 seconds
        setTimeout(() => {
          if (statusElement.innerHTML === this.savedHtml) {
            statusElement.innerHTML = ""
          }
        }, 3000)
        break
      case "error":
        statusElement.innerHTML = this.errorHtml
        statusElement.classList.add("text-red-500")
        break
    }
  }

  // CSRF token for Rails
  get csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  // Status indicator HTML templates
  get typingHtml() {
    return `
      <span class="flex items-center gap-1 text-xs">
        <span class="w-1.5 h-1.5 bg-current rounded-full animate-pulse"></span>
        Editing...
      </span>
    `
  }

  get savingHtml() {
    return `
      <span class="flex items-center gap-1 text-xs">
        <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Saving...
      </span>
    `
  }

  get savedHtml() {
    return `
      <span class="flex items-center gap-1 text-xs">
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        Saved
      </span>
    `
  }

  get errorHtml() {
    return `
      <span class="flex items-center gap-1 text-xs">
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
        Error saving
      </span>
    `
  }
}

