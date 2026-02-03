import { Controller } from "@hotwired/stimulus"

/**
 * Live Filter Controller (Admin Suite)
 *
 * Automatically submits filter forms on input change with debouncing.
 * Works with Turbo Frames to provide smooth, live-updating results.
 */
export default class extends Controller {
  static targets = ["input"]
  static values = {
    debounce: { type: Number, default: 300 },
    minLength: { type: Number, default: 3 },
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  submit() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    this.element.requestSubmit()
  }

  debounce() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.debounceValue)
  }

  debounceWithMinLength(event) {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    const value = event.target.value
    const minLength =
      parseInt(event.target.dataset.adminSuiteLiveFilterMinLengthValue) ||
      this.minLengthValue

    if (value.length === 0 || value.length >= minLength) {
      this.timeout = setTimeout(() => {
        this.element.requestSubmit()
      }, this.debounceValue)
    }
  }

  clear() {
    this.inputTargets.forEach((input) => {
      if (input.type === "checkbox") {
        input.checked = false
      } else {
        input.value = ""
      }
    })
    this.submit()
  }
}

