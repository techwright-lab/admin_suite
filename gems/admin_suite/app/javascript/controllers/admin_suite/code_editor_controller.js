import { Controller } from "@hotwired/stimulus"

/**
 * Code Editor Controller (Admin Suite)
 *
 * Lightweight fallback: keeps a monospace textarea but adds
 * - tab indentation support
 * - auto-resize (optional)
 *
 * If a host app wants a real editor (CodeMirror/Monaco), it can override by
 * replacing this controller via importmap pinning.
 */
export default class extends Controller {
  static targets = ["textarea"]

  connect() {
    if (!this.hasTextareaTarget) return

    this.onKeydown = this.onKeydown.bind(this)
    this.textareaTarget.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    if (!this.hasTextareaTarget) return
    this.textareaTarget.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.key !== "Tab") return

    event.preventDefault()
    const el = this.textareaTarget
    const start = el.selectionStart
    const end = el.selectionEnd
    const value = el.value

    // Insert two spaces on tab.
    el.value = value.substring(0, start) + "  " + value.substring(end)
    el.selectionStart = el.selectionEnd = start + 2

    // Keep Rails form dirty tracking happy.
    el.dispatchEvent(new Event("input", { bubbles: true }))
  }
}

