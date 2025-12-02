import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["overlay", "mobileSidebar"]

  toggle(event) {
    event.preventDefault()
    
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.toggle("hidden")
    }
    
    if (this.hasMobileSidebarTarget) {
      this.mobileSidebarTarget.classList.toggle("hidden")
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
    
    if (this.hasMobileSidebarTarget) {
      this.mobileSidebarTarget.classList.add("hidden")
    }
  }
}

