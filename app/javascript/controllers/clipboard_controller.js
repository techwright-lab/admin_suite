import { Controller } from "@hotwired/stimulus"

// Clipboard controller for copying text to clipboard.
//
// Example:
// <button data-controller="clipboard" 
//         data-action="click->clipboard#copy" 
//         data-clipboard-text-value="Text to copy">
//   Copy
// </button>
export default class extends Controller {
  static values = {
    text: String
  }

  async copy(event) {
    event.preventDefault()
    
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.showFeedback("Copied!")
    } catch (err) {
      // Fallback for older browsers
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
    } catch (err) {
      this.showFeedback("Failed to copy")
    }
    
    document.body.removeChild(textarea)
  }

  showFeedback(message) {
    // Create a small tooltip near the button
    const tooltip = document.createElement("div")
    tooltip.textContent = message
    tooltip.className = "fixed z-50 px-2 py-1 text-xs font-medium text-white bg-gray-900 rounded shadow-lg pointer-events-none transition-opacity duration-200"
    
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

