import { Controller } from "@hotwired/stimulus"

// Collapsible controller for expanding/collapsing content sections
export default class extends Controller {
  static targets = ["content", "icon"]

  toggle() {
    const isHidden = this.contentTarget.classList.contains("hidden")
    
    if (isHidden) {
      this.contentTarget.classList.remove("hidden")
      if (this.hasIconTarget) {
        this.iconTarget.classList.add("rotate-180")
      }
    } else {
      this.contentTarget.classList.add("hidden")
      if (this.hasIconTarget) {
        this.iconTarget.classList.remove("rotate-180")
      }
    }
  }
}

