import { Controller } from "@hotwired/stimulus"

/**
 * Toggle Switch Controller
 * 
 * Simple toggle switch for boolean form fields.
 * Updates hidden input and visual state when clicked.
 * 
 * Usage:
 *   <div data-controller="toggle-switch">
 *     <button data-toggle-switch-target="button" data-action="click->toggle-switch#toggle">
 *       <span data-toggle-switch-target="thumb"></span>
 *     </button>
 *     <input type="hidden" data-toggle-switch-target="input">
 *     <span data-toggle-switch-target="label">Disabled</span>
 *   </div>
 */
export default class extends Controller {
  static targets = ["button", "thumb", "input", "label"]
  static values = {
    fieldId: String
  }

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
    // Update button background (target the button element, not the wrapper)
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

    // Update thumb position
    if (this.hasThumbTarget) {
      if (this.checked) {
        this.thumbTarget.classList.remove("translate-x-0")
        this.thumbTarget.classList.add("translate-x-5")
      } else {
        this.thumbTarget.classList.remove("translate-x-5")
        this.thumbTarget.classList.add("translate-x-0")
      }
    }

    // Update label
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

