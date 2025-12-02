// Tabs controller for switching between tab panels
// Supports URL persistence for tab state and auto-switching from URL params
//
// Example usage:
// <div data-controller="tabs" data-tabs-default-tab-value="overview" data-tabs-persist-value="true">
//   <button data-tabs-target="tab" data-tab="overview" data-action="click->tabs#switch">Overview</button>
//   <div data-tabs-target="panel" data-panel="overview">Content</div>
// </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    defaultTab: { type: String, default: "overview" },
    persist: { type: Boolean, default: true },
    paramName: { type: String, default: "tab" }
  }

  connect() {
    // Check URL for tab parameter first
    const urlTab = this.getTabFromUrl()
    const initialTab = urlTab || this.defaultTabValue
    this.showTab(initialTab, false)
  }

  // Switches to a tab when clicked
  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    this.showTab(tabName, this.persistValue)
  }

  // Shows a specific tab and optionally updates URL
  showTab(tabName, updateUrl = true) {
    // Update tabs styling
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === tabName) {
        tab.classList.add("border-primary-500", "text-primary-600", "dark:text-primary-400")
        tab.classList.remove("border-transparent", "text-gray-500", "dark:text-gray-400", "hover:text-gray-700", "dark:hover:text-gray-300", "hover:border-gray-300", "dark:hover:border-gray-600")
        tab.setAttribute("aria-selected", "true")
      } else {
        tab.classList.remove("border-primary-500", "text-primary-600", "dark:text-primary-400")
        tab.classList.add("border-transparent", "text-gray-500", "dark:text-gray-400", "hover:text-gray-700", "dark:hover:text-gray-300", "hover:border-gray-300", "dark:hover:border-gray-600")
        tab.setAttribute("aria-selected", "false")
      }
    })

    // Update panels visibility
    this.panelTargets.forEach(panel => {
      if (panel.dataset.panel === tabName) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })

    // Update URL if persistence is enabled
    if (updateUrl && this.persistValue) {
      this.updateUrl(tabName)
    }
  }

  // Gets the current tab from URL parameters
  getTabFromUrl() {
    const params = new URLSearchParams(window.location.search)
    return params.get(this.paramNameValue)
  }

  // Updates the URL with the current tab without reloading
  updateUrl(tabName) {
    const url = new URL(window.location)
    url.searchParams.set(this.paramNameValue, tabName)
    window.history.replaceState({}, "", url)
  }
}
