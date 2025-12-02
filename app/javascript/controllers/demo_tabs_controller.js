import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for the homepage demo section tabs
 * Handles tab switching for the interactive demo preview
 */
export default class extends Controller {
  static targets = ["tab", "tabContent", "pipelineItem"]

  connect() {
    this.currentTabIndex = 0
  }

  /**
   * Select a tab and show its content
   * @param {Event} event - Click event from tab button
   */
  selectTab(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.showTab(index)
  }

  /**
   * Select a pipeline item (visual feedback only)
   * @param {Event} event - Click event from pipeline item
   */
  selectPipelineItem(event) {
    // Update active state for pipeline items
    this.pipelineItemTargets.forEach((item, i) => {
      if (parseInt(item.dataset.index) === parseInt(event.currentTarget.dataset.index)) {
        item.classList.remove("bg-white/5", "border-white/5")
        item.classList.add("bg-primary-500/10", "border-primary-500/30")
      } else {
        item.classList.remove("bg-primary-500/10", "border-primary-500/30")
        item.classList.add("bg-white/5", "border-white/5")
      }
    })
  }

  /**
   * Show tab content at specified index
   * @param {number} index - Tab index to show
   */
  showTab(index) {
    this.currentTabIndex = index

    // Update tab styles
    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add("bg-primary-500/20", "text-primary-300")
        tab.classList.remove("text-gray-400", "hover:text-white", "hover:bg-white/5")
      } else {
        tab.classList.remove("bg-primary-500/20", "text-primary-300")
        tab.classList.add("text-gray-400", "hover:text-white", "hover:bg-white/5")
      }
    })

    // Show/hide tab content
    this.tabContentTargets.forEach((content, i) => {
      if (i === index) {
        content.classList.remove("hidden")
      } else {
        content.classList.add("hidden")
      }
    })
  }
}

