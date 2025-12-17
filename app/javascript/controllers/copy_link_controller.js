// Copy current page URL (or provided URL) to clipboard.
//
// Example usage:
// <button data-controller="copy-link"
//         data-copy-link-url-value="https://example.com"
//         data-action="click->copy-link#copy">
//   Copy link
// </button>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    successText: { type: String, default: "Copied!" },
    resetText: { type: String, default: "Copy link" },
    resetAfterMs: { type: Number, default: 1800 },
  }

  connect() {
    this.originalText = this.element.textContent
  }

  async copy() {
    const url = this.hasUrlValue ? this.urlValue : window.location.href

    try {
      await navigator.clipboard.writeText(url)
      this.setText(this.successTextValue)
      window.clearTimeout(this.resetTimer)
      this.resetTimer = window.setTimeout(() => {
        this.setText(this.originalText || this.resetTextValue)
      }, this.resetAfterMsValue)
    } catch (e) {
      // Fallback for older browsers
      this.fallbackCopy(url)
    }
  }

  fallbackCopy(text) {
    const input = document.createElement("input")
    input.value = text
    document.body.appendChild(input)
    input.select()
    document.execCommand("copy")
    input.remove()
    this.setText(this.successTextValue)
  }

  setText(value) {
    this.element.textContent = value
  }
}


