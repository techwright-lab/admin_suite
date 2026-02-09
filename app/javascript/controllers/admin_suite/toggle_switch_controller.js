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
    this.checked = this.inputTarget?.value === "1" || this.inputTarget?.value === "true"
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
    if (this.hasButtonTarget) {
      if (this.checked) {
        this.buttonTarget.classList.remove(...this.inactiveClasses.split(" "))
        this.buttonTarget.classList.add(this.activeClass)
      } else {
        this.buttonTarget.classList.remove(this.activeClass)
        this.buttonTarget.classList.add(...this.inactiveClasses.split(" "))
      }
      this.buttonTarget.setAttribute("aria-checked", this.checked.toString())
    }

    if (this.hasThumbTarget) {
      if (this.checked) {
        this.thumbTarget.classList.remove("translate-x-0")
        this.thumbTarget.classList.add("translate-x-5")
      } else {
        this.thumbTarget.classList.remove("translate-x-5")
        this.thumbTarget.classList.add("translate-x-0")
      }
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
}

