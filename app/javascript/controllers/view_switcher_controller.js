import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="view-switcher"
export default class extends Controller {
  static targets = ["kanbanButton", "listButton"]
  static values = {
    currentView: String
  }

  connect() {
    // Load saved preference from localStorage
    const savedView = localStorage.getItem("preferredView") || this.currentViewValue || "kanban"
    this.updateView(savedView, false)
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
    if (this.hasKanbanButtonTarget && this.hasListButtonTarget) {
      if (view === "kanban") {
        this.kanbanButtonTarget.classList.add("active")
        this.listButtonTarget.classList.remove("active")
      } else {
        this.listButtonTarget.classList.add("active")
        this.kanbanButtonTarget.classList.remove("active")
      }
    }

    // Navigate if needed
    if (navigate) {
      const url = new URL(window.location)
      url.searchParams.set("view", view)
      Turbo.visit(url.toString())
    }
  }
}

