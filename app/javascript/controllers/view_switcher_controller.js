import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="view-switcher"
// Usage:
// <div data-controller="view-switcher">
//   <a data-view="table" data-action="click->view-switcher#switch">Table</a>
//   <a data-view="kanban" data-action="click->view-switcher#switch">Kanban</a>
// </div>
export default class extends Controller {
  static targets = ["kanbanButton", "listButton", "button"]
  static values = {
    currentView: String
  }

  connect() {
    // Load saved preference from localStorage
    const savedView = localStorage.getItem("preferredView") || this.currentViewValue || "kanban"
    this.updateView(savedView, false)
  }

  // Generic switch method that reads the view from data-view attribute
  switch(event) {
    const view = event.currentTarget.dataset.view
    if (view) {
      // Save preference but let the link navigate naturally
      localStorage.setItem("preferredView", view)
      this.updateButtonStates(view)
    }
  }

  switchToKanban(event) {
    event.preventDefault()
    this.updateView("kanban")
  }

  switchToList(event) {
    event.preventDefault()
    this.updateView("list")
  }

  updateView(view, navigate = true) {
    // Save to localStorage
    localStorage.setItem("preferredView", view)
    
    // Update button states
    this.updateButtonStates(view)

    // Navigate if needed
    if (navigate) {
      const url = new URL(window.location)
      url.searchParams.set("view", view)
      Turbo.visit(url.toString())
    }
  }

  updateButtonStates(view) {
    // Update legacy button targets
    if (this.hasKanbanButtonTarget && this.hasListButtonTarget) {
      if (view === "kanban") {
        this.kanbanButtonTarget.classList.add("active")
        this.listButtonTarget.classList.remove("active")
      } else {
        this.listButtonTarget.classList.add("active")
        this.kanbanButtonTarget.classList.remove("active")
      }
    }

    // Update generic button targets with data-view
    if (this.hasButtonTarget) {
      this.buttonTargets.forEach(button => {
        const buttonView = button.dataset.view
        if (buttonView === view) {
          button.classList.add("bg-gray-100", "dark:bg-gray-700", "text-gray-900", "dark:text-white")
          button.classList.remove("text-gray-600", "dark:text-gray-400")
        } else {
          button.classList.remove("bg-gray-100", "dark:bg-gray-700", "text-gray-900", "dark:text-white")
          button.classList.add("text-gray-600", "dark:text-gray-400")
        }
      })
    }
  }
}

