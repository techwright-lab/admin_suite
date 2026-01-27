import { Controller } from "@hotwired/stimulus"

// Dropdown Controller
//
// Provides dropdown menu functionality with support for fixed positioning
// to prevent clipping in scrollable containers.
//
// Example usage:
// <div data-controller="dropdown" data-dropdown-fixed-value="true">
//   <button data-action="click->dropdown#toggle">Toggle</button>
//   <div data-dropdown-target="menu" class="hidden">Menu content</div>
// </div>
export default class extends Controller {
  static targets = ["menu"]
  static values = {
    fixed: { type: Boolean, default: false }
  }

  connect() {
    this.close = this.close.bind(this)
    this.handleScroll = this.handleScroll.bind(this)
    this.triggerButton = null
  }

  toggle(event) {
    event.stopPropagation()
    this.triggerButton = event.currentTarget
    
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // If fixed positioning is enabled, set up positioning first
    if (this.fixedValue && this.triggerButton) {
      this.positionMenu()
    }
    
    this.menuTarget.classList.remove("hidden")
    
    if (this.fixedValue) {
      window.addEventListener("scroll", this.handleScroll, true)
      window.addEventListener("resize", this.close)
    }
    
    // Close dropdown when clicking outside
    setTimeout(() => {
      document.addEventListener("click", this.close)
    }, 0)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.close)
    
    if (this.fixedValue) {
      window.removeEventListener("scroll", this.handleScroll, true)
      window.removeEventListener("resize", this.close)
      // Reset positioning styles
      this.menuTarget.style.position = ""
      this.menuTarget.style.top = ""
      this.menuTarget.style.left = ""
      this.menuTarget.style.right = ""
      this.menuTarget.style.bottom = ""
    }
  }

  // Position menu using fixed coordinates to escape overflow containers
  positionMenu() {
    if (!this.triggerButton) return
    
    const buttonRect = this.triggerButton.getBoundingClientRect()
    const viewportHeight = window.innerHeight
    const viewportWidth = window.innerWidth
    
    // Set fixed position first, then measure
    this.menuTarget.style.position = "fixed"
    this.menuTarget.style.visibility = "hidden"
    this.menuTarget.style.top = "0"
    this.menuTarget.style.left = "0"
    this.menuTarget.classList.remove("hidden")
    
    const menuHeight = this.menuTarget.offsetHeight
    const menuWidth = this.menuTarget.offsetWidth
    
    this.menuTarget.classList.add("hidden")
    this.menuTarget.style.visibility = ""
    
    // Determine if menu should open upward or downward
    const spaceBelow = viewportHeight - buttonRect.bottom
    const spaceAbove = buttonRect.top
    const openUpward = spaceBelow < menuHeight + 8 && spaceAbove > spaceBelow
    
    // Calculate position
    let top, left
    
    if (openUpward) {
      top = buttonRect.top - menuHeight - 4
    } else {
      top = buttonRect.bottom + 4
    }
    
    // Align to right edge of button
    left = buttonRect.right - menuWidth
    
    // Ensure menu stays within viewport
    if (left < 8) {
      left = 8
    }
    if (left + menuWidth > viewportWidth - 8) {
      left = viewportWidth - menuWidth - 8
    }
    if (top < 8) {
      top = 8
    }
    if (top + menuHeight > viewportHeight - 8) {
      top = viewportHeight - menuHeight - 8
    }
    
    // Apply positioning
    this.menuTarget.style.top = `${top}px`
    this.menuTarget.style.left = `${left}px`
    this.menuTarget.style.right = "auto"
    this.menuTarget.style.bottom = "auto"
  }

  handleScroll() {
    // Close menu on scroll to prevent misalignment
    this.close()
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    window.removeEventListener("scroll", this.handleScroll, true)
    window.removeEventListener("resize", this.close)
  }
}

