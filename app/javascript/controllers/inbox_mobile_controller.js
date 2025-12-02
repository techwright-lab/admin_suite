import { Controller } from "@hotwired/stimulus"

/**
 * InboxMobileController
 * 
 * Handles mobile-specific inbox behavior:
 * - Opens full-screen modal when clicking email on mobile
 * - Handles back navigation
 * - Manages scroll position
 */
export default class extends Controller {
  static targets = ["list", "detail", "modal"]
  
  connect() {
    this.scrollPosition = 0
    this.isMobile = window.innerWidth < 1024 // lg breakpoint
    
    // Listen for resize to update mobile state
    this.resizeHandler = this.handleResize.bind(this)
    window.addEventListener("resize", this.resizeHandler)
    
    // Listen for turbo frame load to update mobile modal
    this.frameLoadHandler = this.handleFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.frameLoadHandler)
  }
  
  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
    document.removeEventListener("turbo:frame-load", this.frameLoadHandler)
  }
  
  /**
   * Opens email detail on mobile
   * @param {Event} event - Click event
   */
  openEmail(event) {
    if (!this.isMobile) return
    
    // Save scroll position
    this.scrollPosition = window.scrollY
    
    // Open modal
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("translate-x-full")
      this.modalTarget.classList.add("translate-x-0")
      
      // Prevent body scroll
      document.body.style.overflow = "hidden"
    }
  }
  
  /**
   * Closes the mobile modal
   */
  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("translate-x-full")
      this.modalTarget.classList.remove("translate-x-0")
      
      // Restore body scroll
      document.body.style.overflow = ""
      
      // Restore scroll position
      setTimeout(() => {
        window.scrollTo(0, this.scrollPosition)
      }, 100)
    }
  }
  
  /**
   * Handles window resize
   */
  handleResize() {
    this.isMobile = window.innerWidth < 1024
    
    // Close modal if resizing to desktop
    if (!this.isMobile && this.hasModalTarget) {
      this.modalTarget.classList.add("translate-x-full")
      this.modalTarget.classList.remove("translate-x-0")
      document.body.style.overflow = ""
    }
  }
  
  /**
   * Handles turbo frame load - copy content to mobile modal if needed
   * @param {Event} event - Turbo frame load event
   */
  handleFrameLoad(event) {
    if (event.target.id === "email_detail" && this.isMobile) {
      // Copy the desktop frame content to mobile modal frame
      const mobileFrame = document.getElementById("email_detail_mobile")
      if (mobileFrame && event.target.innerHTML) {
        mobileFrame.innerHTML = event.target.innerHTML
      }
    }
  }
}

