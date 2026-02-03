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
  static values = {
    selectedClasses: { type: Array, default: ["bg-primary-50", "dark:bg-primary-900/20"] }
  }
  
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
    // Always mark which row is currently being viewed (desktop + mobile).
    // This is purely visual; the actual content loads via Turbo Frame.
    this.markRowSelected(event.currentTarget)

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
   * Marks the clicked row as the active (currently viewed) signal.
   *
   * @param {HTMLElement} clickedRow
   */
  markRowSelected(clickedRow) {
    if (!clickedRow) return
    if (!clickedRow.dataset || clickedRow.dataset.signalRow !== "true") return

    const selected = this.selectedClassesValue
    const rows = this.element.querySelectorAll('[data-signal-row="true"]')

    rows.forEach((row) => {
      row.classList.remove(...selected)
      row.removeAttribute("aria-current")

      const indicator = row.querySelector("[data-signal-row-indicator]")
      indicator?.classList.add("hidden")
    })

    clickedRow.classList.add(...selected)
    clickedRow.setAttribute("aria-current", "true")

    const clickedIndicator = clickedRow.querySelector("[data-signal-row-indicator]")
    clickedIndicator?.classList.remove("hidden")
  }

  /**
   * Ensure "Load more" requests preserve current selection highlighting by
   * injecting selected_email_id into the link before Turbo handles navigation.
   *
   * Attach this to pointerdown (or mousedown) on the link.
   *
   * @param {Event} event
   */
  prepareLoadMore(event) {
    const selectedRow = this.element.querySelector('[data-signal-row="true"][aria-current="true"]')
    const selectedEmailId = selectedRow?.dataset?.signalEmailId
    if (!selectedEmailId) return

    const link = event.currentTarget
    if (!link?.href) return

    const url = new URL(link.href, window.location.origin)
    url.searchParams.set("selected_email_id", selectedEmailId)
    link.href = url.toString()
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

