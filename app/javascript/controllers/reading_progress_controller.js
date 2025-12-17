import { Controller } from "@hotwired/stimulus"

/**
 * Updates a progress bar target based on scroll position.
 *
 * Usage:
 * <div data-controller="reading-progress">
 *   <div data-reading-progress-target="bar"></div>
 * </div>
 */
export default class extends Controller {
  static targets = ["bar"]

  connect() {
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.handleScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  handleScroll() {
    if (!this.hasBarTarget) return

    const maxScroll = document.documentElement.scrollHeight - window.innerHeight
    const progress = maxScroll > 0 ? (window.scrollY / maxScroll) * 100 : 0
    const clamped = Math.max(0, Math.min(100, progress))
    this.barTarget.style.width = `${clamped}%`
  }
}

