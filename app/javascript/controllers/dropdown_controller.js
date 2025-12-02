import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    
    // Close dropdown when clicking outside
    setTimeout(() => {
      document.addEventListener("click", this.close)
    }, 0)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.close)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
  }
}

