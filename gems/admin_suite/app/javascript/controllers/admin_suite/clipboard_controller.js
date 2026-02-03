import { Controller } from "@hotwired/stimulus"

// Clipboard controller (Admin Suite) for copying text to clipboard.
export default class extends Controller {
  static values = {
    text: String,
  }

  async copy(event) {
    event.preventDefault()

    try {
      await navigator.clipboard.writeText(this.textValue)
      this.showFeedback("Copied!")
    } catch (_err) {
      this.fallbackCopy(this.textValue)
    }
  }

  fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()

    try {
      document.execCommand("copy")
      this.showFeedback("Copied!")
    } catch (_err) {
      this.showFeedback("Failed to copy")
    }

    document.body.removeChild(textarea)
  }

  showFeedback(message) {
    const tooltip = document.createElement("div")
    tooltip.textContent = message
    tooltip.className =
      "fixed z-50 px-2 py-1 text-xs font-medium text-white bg-gray-900 rounded shadow-lg pointer-events-none transition-opacity duration-200"

    const rect = this.element.getBoundingClientRect()
    tooltip.style.top = `${rect.top - 30}px`
    tooltip.style.left = `${rect.left + rect.width / 2}px`
    tooltip.style.transform = "translateX(-50%)"

    document.body.appendChild(tooltip)

    setTimeout(() => {
      tooltip.style.opacity = "0"
      setTimeout(() => tooltip.remove(), 200)
    }, 1000)
  }
}

