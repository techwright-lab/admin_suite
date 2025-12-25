import { Controller } from "@hotwired/stimulus"

/**
 * Toggle Controller
 * 
 * Manages toggle switch state for boolean form fields.
 * Provides accessible toggle button with visual feedback.
 * 
 * Usage:
 *   <div data-controller="toggle" data-toggle-checked-value="true">
 *     <button type="button"
 *       data-toggle-target="button"
 *       data-action="toggle#toggle"
 *       role="switch"
 *       aria-checked="true">
 *       <span data-toggle-target="indicator"></span>
 *     </button>
 *     <input type="hidden" data-toggle-target="input" value="true">
 *   </div>
 */
export default class extends Controller {
  static targets = ["button", "input", "indicator"]
  static values = {
    checked: { type: Boolean, default: false }
  }

  // CSS classes for different states
  static classes = ["active", "inactive", "indicatorActive", "indicatorInactive"]

  connect() {
    // Initialize state from input value
    if (this.hasInputTarget) {
      this.checkedValue = this.inputTarget.value === "true" || this.inputTarget.value === "1"
    }
    this.updateUI()
  }

  /**
   * Toggles the switch state
   */
  toggle(event) {
    event.preventDefault()
    this.checkedValue = !this.checkedValue
  }

  /**
   * Sets the switch to on
   */
  on() {
    this.checkedValue = true
  }

  /**
   * Sets the switch to off
   */
  off() {
    this.checkedValue = false
  }

  /**
   * Called when checkedValue changes
   */
  checkedValueChanged() {
    this.updateUI()
    this.updateInput()
    this.dispatch("change", { detail: { checked: this.checkedValue } })
  }

  /**
   * Updates the visual state of the toggle
   */
  updateUI() {
    if (!this.hasButtonTarget) return

    // Update aria-checked
    this.buttonTarget.setAttribute("aria-checked", this.checkedValue)

    // Update button classes
    if (this.checkedValue) {
      this.buttonTarget.classList.remove("bg-slate-300", "dark:bg-slate-600")
      this.buttonTarget.classList.add("bg-amber-500")
    } else {
      this.buttonTarget.classList.remove("bg-amber-500")
      this.buttonTarget.classList.add("bg-slate-300", "dark:bg-slate-600")
    }

    // Update indicator position
    if (this.hasIndicatorTarget) {
      if (this.checkedValue) {
        this.indicatorTarget.classList.remove("translate-x-1")
        this.indicatorTarget.classList.add("translate-x-6")
      } else {
        this.indicatorTarget.classList.remove("translate-x-6")
        this.indicatorTarget.classList.add("translate-x-1")
      }
    }
  }

  /**
   * Updates the hidden input value
   */
  updateInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = this.checkedValue ? "true" : "false"
    }
  }
}

