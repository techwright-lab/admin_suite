import { Controller } from "@hotwired/stimulus"

// AI assistant floating drawer controller.
//
// Features:
// - Toggle drawer open/close
// - Smooth animations
// - Escape key to close
// - Global keyboard shortcut (Cmd+J)
// - Persist state in sessionStorage
//
// Example:
// <div data-controller="ai-assistant">
//   <button data-action="click->ai-assistant#toggle"></button>
//   <div data-ai-assistant-target="drawer" class="hidden"></div>
// </div>
export default class extends Controller {
  static targets = ["drawer", "button", "backdrop"]

  connect() {
    this.setupKeyboardShortcut()
    this.restoreState()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleGlobalKeydown)
  }

  toggle(event) {
    if (event) event.preventDefault()
    
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
    }
    
    // Show drawer and trigger animation
    this.drawerTarget.classList.remove("translate-y-full", "md:translate-x-full", "md:opacity-0")
    this.drawerTarget.classList.add("translate-y-0", "md:translate-x-0", "md:opacity-100")
    
    // Focus the drawer for keyboard events
    this.drawerTarget.focus()
    
    // Hide the floating button
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.add("scale-0", "opacity-0")
    }
    
    this.saveState(true)
  }

  close() {
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }
    
    // Hide drawer with animation
    this.drawerTarget.classList.add("translate-y-full", "md:translate-x-full", "md:opacity-0")
    this.drawerTarget.classList.remove("translate-y-0", "md:translate-x-0", "md:opacity-100")
    
    // Show the floating button
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("scale-0", "opacity-0")
    }
    
    this.saveState(false)
  }

  isOpen() {
    return !this.drawerTarget.classList.contains("translate-y-full") && 
           !this.drawerTarget.classList.contains("md:translate-x-full")
  }

  // Setup global keyboard shortcut (Cmd/Ctrl + J)
  setupKeyboardShortcut() {
    this.handleGlobalKeydown = (event) => {
      // Cmd/Ctrl + J to toggle
      if ((event.metaKey || event.ctrlKey) && event.key === "j") {
        event.preventDefault()
        this.toggle()
      }
    }
    
    document.addEventListener("keydown", this.handleGlobalKeydown)
  }

  // Save state to sessionStorage
  saveState(isOpen) {
    try {
      sessionStorage.setItem("ai_assistant_open", isOpen ? "true" : "false")
    } catch (e) {
      // sessionStorage may not be available
    }
  }

  // Restore state from sessionStorage
  restoreState() {
    try {
      const wasOpen = sessionStorage.getItem("ai_assistant_open") === "true"
      if (wasOpen) {
        // Delay slightly to ensure DOM is ready
        requestAnimationFrame(() => this.open())
      }
    } catch (e) {
      // sessionStorage may not be available
    }
  }
}
