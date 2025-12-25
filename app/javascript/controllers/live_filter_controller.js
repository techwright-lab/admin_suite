import { Controller } from "@hotwired/stimulus"

/**
 * Live Filter Controller
 * 
 * Automatically submits filter forms on input change with debouncing.
 * Works with Turbo Frames to provide smooth, live-updating results.
 * 
 * Usage:
 *   <form data-controller="live-filter" data-turbo-frame="results">
 *     <input data-live-filter-target="input" data-action="input->live-filter#debounce">
 *     <input data-live-filter-target="input" data-action="input->live-filter#debounceWithMinLength" 
 *            data-live-filter-min-length-value="3">
 *     <select data-action="change->live-filter#submit">
 *   </form>
 */
export default class extends Controller {
  static targets = ["input"]
  static values = {
    debounce: { type: Number, default: 300 },
    minLength: { type: Number, default: 3 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  /**
   * Submits the form immediately
   */
  submit() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    this.element.requestSubmit()
  }

  /**
   * Submits the form after a debounce delay
   * Used for text inputs to avoid submitting on every keystroke
   */
  debounce() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.debounceValue)
  }

  /**
   * Submits the form after a debounce delay, but only if minimum length is met
   * Used for search inputs where we want to avoid submitting short queries
   * @param {Event} event - The input event
   */
  debounceWithMinLength(event) {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    
    const value = event.target.value
    const minLength = parseInt(event.target.dataset.liveFilterMinLengthValue) || this.minLengthValue
    
    // Only submit if value is empty (to clear search) or meets minimum length
    if (value.length === 0 || value.length >= minLength) {
      this.timeout = setTimeout(() => {
        this.element.requestSubmit()
      }, this.debounceValue)
    }
  }

  /**
   * Clears all inputs and submits the form
   */
  clear() {
    this.inputTargets.forEach(input => {
      if (input.type === "checkbox") {
        input.checked = false
      } else {
        input.value = ""
      }
    })
    this.submit()
  }
}

