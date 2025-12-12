// JSON Editor Controller
// Provides JSON validation, formatting, and editing for JSON fields in admin forms
//
// Example usage:
// <div data-controller="json-editor">
//   <textarea data-json-editor-target="input" data-action="input->json-editor#validate"></textarea>
//   <div data-json-editor-target="error" class="hidden"></div>
//   <button data-action="click->json-editor#format">Format</button>
// </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "error"]

  // Validates JSON on input
  validate() {
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value.trim()
    
    // Clear error if empty
    if (value === "") {
      this.clearError()
      return
    }

    try {
      JSON.parse(value)
      this.clearError()
      this.inputTarget.classList.remove("border-red-500", "dark:border-red-500")
      this.inputTarget.classList.add("border-slate-300", "dark:border-slate-600")
    } catch (e) {
      this.showError(e.message)
      this.inputTarget.classList.remove("border-slate-300", "dark:border-slate-600")
      this.inputTarget.classList.add("border-red-500", "dark:border-red-500")
    }
  }

  // Formats/pretty-prints the JSON
  format(event) {
    event?.preventDefault()
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value.trim()
    
    if (value === "") {
      return
    }

    try {
      const parsed = JSON.parse(value)
      const formatted = JSON.stringify(parsed, null, 2)
      this.inputTarget.value = formatted
      this.clearError()
      this.inputTarget.classList.remove("border-red-500", "dark:border-red-500")
      this.inputTarget.classList.add("border-slate-300", "dark:border-slate-600")
    } catch (e) {
      this.showError(e.message)
      this.inputTarget.classList.remove("border-slate-300", "dark:border-slate-600")
      this.inputTarget.classList.add("border-red-500", "dark:border-red-500")
    }
  }

  // Shows validation error
  showError(message) {
    if (!this.hasErrorTarget) return
    
    this.errorTarget.textContent = `Invalid JSON: ${message}`
    this.errorTarget.classList.remove("hidden")
  }

  // Clears validation error
  clearError() {
    if (!this.hasErrorTarget) return
    
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}

