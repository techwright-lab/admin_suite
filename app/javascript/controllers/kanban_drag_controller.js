// Kanban Drag Controller
//
// Enables drag-and-drop functionality for kanban cards across pipeline stage columns.
// Uses native HTML5 Drag and Drop API with visual feedback.
//
// Example usage:
// <div data-controller="kanban-drag" data-kanban-drag-url-value="/applications">
//   <div data-kanban-drag-target="column" data-stage="screening">
//     <div data-kanban-drag-target="card" data-application-id="123" draggable="true">
//       Card content
//     </div>
//   </div>
// </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["column", "card"]
  static values = {
    url: String
  }

  connect() {
    this.draggedCard = null
    this.sourceColumn = null
    this.setupDragEvents()
  }

  disconnect() {
    this.cleanupDragEvents()
  }

  setupDragEvents() {
    this.cardTargets.forEach(card => {
      card.addEventListener("dragstart", this.handleDragStart.bind(this))
      card.addEventListener("dragend", this.handleDragEnd.bind(this))
    })

    this.columnTargets.forEach(column => {
      column.addEventListener("dragover", this.handleDragOver.bind(this))
      column.addEventListener("dragenter", this.handleDragEnter.bind(this))
      column.addEventListener("dragleave", this.handleDragLeave.bind(this))
      column.addEventListener("drop", this.handleDrop.bind(this))
    })
  }

  cleanupDragEvents() {
    this.cardTargets.forEach(card => {
      card.removeEventListener("dragstart", this.handleDragStart.bind(this))
      card.removeEventListener("dragend", this.handleDragEnd.bind(this))
    })

    this.columnTargets.forEach(column => {
      column.removeEventListener("dragover", this.handleDragOver.bind(this))
      column.removeEventListener("dragenter", this.handleDragEnter.bind(this))
      column.removeEventListener("dragleave", this.handleDragLeave.bind(this))
      column.removeEventListener("drop", this.handleDrop.bind(this))
    })
  }

  handleDragStart(event) {
    this.draggedCard = event.currentTarget
    this.sourceColumn = this.draggedCard.closest("[data-kanban-drag-target='column']")
    
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedCard.dataset.applicationId)
    
    requestAnimationFrame(() => {
      this.draggedCard.classList.add("opacity-50", "scale-95")
    })
  }

  handleDragEnd(event) {
    if (this.draggedCard) {
      this.draggedCard.classList.remove("opacity-50", "scale-95")
    }
    
    this.columnTargets.forEach(column => {
      column.classList.remove("ring-2", "ring-primary-500", "ring-offset-2", "bg-primary-50", "dark:bg-primary-900/10")
    })
    
    this.draggedCard = null
    this.sourceColumn = null
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  handleDragEnter(event) {
    event.preventDefault()
    const column = event.currentTarget
    
    if (column !== this.sourceColumn) {
      column.classList.add("ring-2", "ring-primary-500", "ring-offset-2", "bg-primary-50", "dark:bg-primary-900/10")
    }
  }

  handleDragLeave(event) {
    const column = event.currentTarget
    
    if (!column.contains(event.relatedTarget)) {
      column.classList.remove("ring-2", "ring-primary-500", "ring-offset-2", "bg-primary-50", "dark:bg-primary-900/10")
    }
  }

  handleDrop(event) {
    event.preventDefault()
    
    const targetColumn = event.currentTarget
    const targetStage = targetColumn.dataset.stage
    const applicationId = event.dataTransfer.getData("text/plain")
    
    targetColumn.classList.remove("ring-2", "ring-primary-500", "ring-offset-2", "bg-primary-50", "dark:bg-primary-900/10")
    
    if (targetColumn === this.sourceColumn) {
      return
    }
    
    if (this.draggedCard) {
      const cardContainer = targetColumn.querySelector("[data-cards]")
      if (cardContainer) {
        cardContainer.appendChild(this.draggedCard)
      }
    }
    
    this.updatePipelineStage(applicationId, targetStage)
  }

  async updatePipelineStage(applicationId, targetStage) {
    const url = `${this.urlValue}/${applicationId}/update_pipeline_stage`
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    
    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ pipeline_stage: targetStage })
      })
      
      if (response.ok) {
        this.showNotice(`Moved to ${this.humanize(targetStage)}`)
        this.updateColumnCounts()
      } else {
        const data = await response.json()
        this.showAlert(data.errors?.[0] || "Failed to update stage")
        window.location.reload()
      }
    } catch (error) {
      console.error("Error updating pipeline stage:", error)
      this.showAlert("An error occurred. Please try again.")
      window.location.reload()
    }
  }

  updateColumnCounts() {
    this.columnTargets.forEach(column => {
      const countBadge = column.querySelector("[data-count]")
      const cardContainer = column.querySelector("[data-cards]")
      
      if (countBadge && cardContainer) {
        const cardCount = cardContainer.querySelectorAll("[data-kanban-drag-target='card']").length
        countBadge.textContent = cardCount
      }
    })
  }

  humanize(str) {
    return str.replace(/_/g, " ").replace(/\b\w/g, char => char.toUpperCase())
  }

  showNotice(message) {
    this.showFlash(message, "notice")
  }

  showAlert(message) {
    this.showFlash(message, "alert")
  }

  showFlash(message, type) {
    const flashContainer = document.getElementById("flash")
    if (!flashContainer) return

    const isNotice = type === "notice"
    const bgClass = isNotice ? "bg-green-50 dark:bg-green-900/20" : "bg-red-50 dark:bg-red-900/20"
    const textClass = isNotice ? "text-green-800 dark:text-green-200" : "text-red-800 dark:text-red-200"
    const iconColor = isNotice ? "text-green-400" : "text-red-400"
    const iconPath = isNotice 
      ? "M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
      : "M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"

    flashContainer.innerHTML = `
      <div class="rounded-md ${bgClass} p-4 mb-4" data-controller="flash">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 ${iconColor}" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="${iconPath}" clip-rule="evenodd"/>
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm font-medium ${textClass}">${message}</p>
          </div>
        </div>
      </div>
    `

    setTimeout(() => {
      flashContainer.innerHTML = ""
    }, 3000)
  }
}
