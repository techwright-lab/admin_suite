import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for the public header navigation
 * Handles mobile menu toggle and scroll-based styling
 */
export default class extends Controller {
  static targets = ["mobileMenu"]

  connect() {
    this.menuOpen = false
    this.setupScrollListener()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  /**
   * Toggle mobile menu visibility
   */
  toggleMenu() {
    this.menuOpen = !this.menuOpen
    
    if (this.hasMobileMenuTarget) {
      if (this.menuOpen) {
        this.mobileMenuTarget.classList.remove("hidden")
      } else {
        this.mobileMenuTarget.classList.add("hidden")
      }
    }
  }

  /**
   * Setup scroll listener for header background changes
   */
  setupScrollListener() {
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.handleScroll() // Initial check
  }

  /**
   * Handle scroll events to update header styling
   */
  handleScroll() {
    const scrolled = window.scrollY > 50

    if (scrolled) {
      this.element.classList.add("bg-dark-950/80", "backdrop-blur-lg", "border-b", "border-white/5")
    } else {
      this.element.classList.remove("bg-dark-950/80", "backdrop-blur-lg", "border-b", "border-white/5")
    }
  }
}

