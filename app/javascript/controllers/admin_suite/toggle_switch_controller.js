import { Controller } from "@hotwired/stimulus"

/**
 * Toggle Switch Controller (Admin Suite)
 */
export default class extends Controller {
  static targets = ["button", "thumb", "input", "label"]
  static values = {
    activeClass: String,
    inactiveClasses: String
  }

  connect() {
    const inputValue = this.hasInputTarget ? this.inputTarget.value : "0"
    this.checked = inputValue === "1" || inputValue === "true"
    this.updateVisual()
  }

  get activeClass() {
    return this.hasActiveClassValue ? this.activeClassValue : "bg-indigo-600"
  }

  get inactiveClasses() {
    return this.hasInactiveClassesValue ? this.inactiveClassesValue : "bg-slate-200"
  }

  toggle(event) {
    event.preventDefault()
    this.checked = !this.checked
    this.updateVisual()
    this.updateInput()
  }

  updateVisual() {
    const inactiveTokens = this.classTokens(this.inactiveClasses)

    if (this.hasButtonTarget) {
      if (this.checked) {
        if (inactiveTokens.length > 0) {
          this.buttonTarget.classList.remove(...inactiveTokens)
        }
        if (this.activeClass) {
          this.buttonTarget.classList.add(this.activeClass)
        }
      } else {
        if (this.activeClass) {
          this.buttonTarget.classList.remove(this.activeClass)
        }
        if (inactiveTokens.length > 0) {
          this.buttonTarget.classList.add(...inactiveTokens)
        }
      }
      this.buttonTarget.setAttribute("aria-checked", this.checked.toString())
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.checked ? "Enabled" : "Disabled"
    }
  }

  updateInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = this.checked ? "1" : "0"
    }
  }

  classTokens(value) {
    return value
      .toString()
      .split(/\s+/)
      .map((token) => token.trim())
      .filter((token) => token.length > 0)
  }
}

