import { Controller } from "@hotwired/stimulus"

// Adds a stable client_request_uuid to a form to make POST actions idempotent.
//
// Example:
// <form data-controller="idempotency-key" data-idempotency-key-name-value="client_request_uuid">
//   <input type="hidden" name="client_request_uuid" value="" />
// </form>
export default class extends Controller {
  static values = {
    name: { type: String, default: "client_request_uuid" },
  }

  connect() {
    this.ensureKey()
  }

  ensureKey() {
    const input = this.element.querySelector(`input[name="${this.nameValue}"]`)
    if (!input) return
    if (input.value) return
    input.value = this.generateUuid()
  }

  generateUuid() {
    if (window.crypto?.randomUUID) return window.crypto.randomUUID()
    const bytes = window.crypto?.getRandomValues ? window.crypto.getRandomValues(new Uint8Array(16)) : null
    if (!bytes) return `${Date.now()}-${Math.random()}`
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("")
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  }
}

