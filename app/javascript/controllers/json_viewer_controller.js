// JSON Viewer Controller
// Provides copy functionality for JSON content in admin views
//
// Example usage:
// <div data-controller="json-viewer">
//   <button data-action="click->json-viewer#copy">Copy</button>
//   <pre data-json-viewer-target="content">{"key": "value"}</pre>
// </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  // Copies the JSON content to clipboard
  async copy(event) {
    if (!this.hasContentTarget) return

    const content = this.contentTarget.textContent
    const button = event.currentTarget

    try {
      await navigator.clipboard.writeText(content)
      
      // Show feedback
      const originalText = button.textContent
      button.textContent = "Copied!"
      button.classList.add("bg-green-100", "dark:bg-green-900/30", "text-green-600", "dark:text-green-400")
      
      setTimeout(() => {
        button.textContent = originalText
        button.classList.remove("bg-green-100", "dark:bg-green-900/30", "text-green-600", "dark:text-green-400")
      }, 2000)
    } catch (err) {
      console.error("Failed to copy:", err)
      button.textContent = "Failed"
      setTimeout(() => {
        button.textContent = "Copy"
      }, 2000)
    }
  }

  // Toggles word wrap on the content
  toggleWrap() {
    if (!this.hasContentTarget) return
    
    this.contentTarget.classList.toggle("whitespace-pre-wrap")
    this.contentTarget.classList.toggle("whitespace-pre")
  }
}

