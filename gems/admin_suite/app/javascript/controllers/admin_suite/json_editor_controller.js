import { Controller } from "@hotwired/stimulus"

// JSON Editor Controller (Admin Suite)
export default class extends Controller {
  static targets = ["input", "error"]

  validate() {
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value.trim()

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

  format(event) {
    event?.preventDefault()
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value.trim()
    if (value === "") return

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

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = `Invalid JSON: ${message}`
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}

