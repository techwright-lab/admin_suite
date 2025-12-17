import { Controller } from "@hotwired/stimulus"

/**
 * Adds lightweight submit feedback (disable + spinner text).
 *
 * Usage:
 * <form data-controller="newsletter-form" data-action="submit->newsletter-form#submit">
 *   <button data-newsletter-form-target="button">Subscribe</button>
 * </form>
 */
export default class extends Controller {
  static targets = ["button"]

  connect() {
    if (this.hasButtonTarget) {
      this.originalButtonHtml = this.buttonTarget.innerHTML
    }
  }

  submit() {
    if (!this.hasButtonTarget) return
    if (this.buttonTarget.disabled) return

    this.buttonTarget.disabled = true
    this.buttonTarget.classList.add("opacity-80", "cursor-not-allowed")
    this.buttonTarget.innerHTML = `
      <svg class="w-4 h-4 mr-2 animate-spin" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
      </svg>
      Subscribing...
    `
  }
}

