import { Controller } from "@hotwired/stimulus"

/**
 * Toggle Switch Controller (Admin Suite)
 */
export default class extends Controller {
  static targets = ["button", "thumb", "input", "label"]

  connect() {
    this.checked = this.inputTarget?.value === "1" || this.inputTarget?.value === "true"
    this.updateVisual()
  }

  toggle(event) {
    event.preventDefault()
    this.checked = !this.checked
    this.updateVisual()
    this.updateInput()
  }

  updateVisual() {
    if (this.hasButtonTarget) {
      if (this.checked) {
        this.buttonTarget.classList.remove("bg-slate-200", "dark:bg-slate-700")
        this.buttonTarget.classList.add("bg-indigo-600")
      } else {
        this.buttonTarget.classList.remove("bg-indigo-600")
        this.buttonTarget.classList.add("bg-slate-200", "dark:bg-slate-700")
      }
      this.buttonTarget.setAttribute("aria-checked", this.checked.toString())
    }

    if (this.hasThumbTarget) {
      if (this.checked) {
        this.thumbTarget.classList.remove("translate-x-0")
        this.thumbTarget.classList.add("translate-x-5")
      } else {
        this.thumbTarget.classList.remove("translate-x-5")
        this.thumbTarget.classList.add("translate-x-0")
      }
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.checked ? "Enabled" : "Disabled"
    }
  }

  updateInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = this.checked ? "1" : "0"
    }
  }
}

