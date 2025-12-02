import { Controller } from "@hotwired/stimulus"

/**
 * ExpandableController
 * 
 * Handles expand/collapse functionality for content areas.
 * Used in email views to show/hide email bodies.
 * 
 * Usage:
 *   <div data-controller="expandable">
 *     <button data-action="click->expandable#toggle">Toggle</button>
 *     <div data-expandable-target="content" class="hidden">Hidden content</div>
 *     <svg data-expandable-target="icon">...</svg>
 *   </div>
 */
export default class extends Controller {
  static targets = ["collapsed", "expanded", "content", "icon", "button"]
  static values = { 
    expanded: { type: Boolean, default: false }
  }
  
  connect() {
    this.updateState()
  }
  
  /**
   * Toggles between expanded and collapsed state
   */
  toggle(event) {
    if (event) event.preventDefault()
    this.expandedValue = !this.expandedValue
    this.updateState()
  }
  
  /**
   * Expands the content
   */
  expand() {
    this.expandedValue = true
    this.updateState()
  }
  
  /**
   * Collapses the content
   */
  collapse() {
    this.expandedValue = false
    this.updateState()
  }
  
  /**
   * Updates the visual state based on expandedValue
   */
  updateState() {
    // Handle collapsed/expanded pair (for dual-view toggle)
    if (this.hasCollapsedTarget) {
      this.collapsedTarget.classList.toggle("hidden", this.expandedValue)
    }
    
    if (this.hasExpandedTarget) {
      this.expandedTarget.classList.toggle("hidden", !this.expandedValue)
    }
    
    // Handle simple content toggle (shows when expanded)
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.expandedValue)
    }
    
    // Rotate icon when expanded
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.expandedValue)
    }
  }
}
