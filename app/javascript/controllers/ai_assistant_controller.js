import { Controller } from "@hotwired/stimulus"

// AI assistant side panel controller.
//
// The panel is integrated into the page layout (not a modal overlay).
// It slides in from the right edge, pushing/shrinking the main content.
//
// Features:
// - Slide-in side panel (no backdrop)
// - Smooth width transition
// - Escape key to close
// - Click outside to close
// - Global keyboard shortcut (Cmd+J)
// - Persist state in sessionStorage
//
// Example:
// <body data-controller="ai-assistant">
//   <div data-ai-assistant-target="mainContent">...</div>
//   <aside data-ai-assistant-target="panel" class="w-0">...</aside>
//   <button data-ai-assistant-target="button" data-action="click->ai-assistant#toggle"></button>
// </body>
export default class extends Controller {
  static targets = ["panel", "button", "mainContent"]

  // Panel width classes
  static panelOpenClasses = ["w-[420px]", "lg:w-[480px]"]
  static panelClosedClasses = ["w-0"]

  connect() {
    this.setupKeyboardShortcut()
    this.setupOutsideClickHandler()
    this.restoreState()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleGlobalKeydown)
    document.removeEventListener("click", this.handleOutsideClick)
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
    if (!this.hasPanelTarget) return
    
    // Expand panel width
    this.constructor.panelClosedClasses.forEach(cls => {
      this.panelTarget.classList.remove(cls)
    })
    this.constructor.panelOpenClasses.forEach(cls => {
      this.panelTarget.classList.add(cls)
    })
    
    // Focus the panel for keyboard events
    this.panelTarget.focus()
    
    // Hide the floating button
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.add("scale-0", "opacity-0", "pointer-events-none")
    }
    
    this.saveState(true)
  }

  close() {
    if (!this.hasPanelTarget) return
    
    // Collapse panel width
    this.constructor.panelOpenClasses.forEach(cls => {
      this.panelTarget.classList.remove(cls)
    })
    this.constructor.panelClosedClasses.forEach(cls => {
      this.panelTarget.classList.add(cls)
    })
    
    // Show the floating button
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("scale-0", "opacity-0", "pointer-events-none")
    }
    
    this.saveState(false)
  }

  isOpen() {
    if (!this.hasPanelTarget) return false
    return this.constructor.panelOpenClasses.some(cls => 
      this.panelTarget.classList.contains(cls)
    )
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

  // Setup click outside handler to close panel
  setupOutsideClickHandler() {
    this.handleOutsideClick = (event) => {
      if (!this.isOpen()) return
      
      // Don't close if clicking inside the panel
      if (this.hasPanelTarget && this.panelTarget.contains(event.target)) return
      
      // Don't close if clicking the toggle button
      if (this.hasButtonTarget && this.buttonTarget.contains(event.target)) return
      
      // Close the panel
      this.close()
    }
    
    document.addEventListener("click", this.handleOutsideClick)
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
