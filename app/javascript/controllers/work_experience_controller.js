import { Controller } from "@hotwired/stimulus"

/**
 * Work Experience Controller
 * Handles add/edit form toggling and current job checkbox behavior
 */
export default class extends Controller {
  static targets = ["addForm", "endDate", "currentCheckbox", "item"]

  connect() {
    // Initialize state
  }

  /**
   * Shows the add experience form
   */
  showAddForm() {
    if (this.hasAddFormTarget) {
      this.addFormTarget.classList.remove("hidden")
      // Focus the first input
      const firstInput = this.addFormTarget.querySelector("input[type='text']")
      if (firstInput) {
        firstInput.focus()
      }
    }
  }

  /**
   * Hides the add experience form
   */
  hideAddForm() {
    if (this.hasAddFormTarget) {
      this.addFormTarget.classList.add("hidden")
      // Reset form
      const form = this.addFormTarget.querySelector("form")
      if (form) {
        form.reset()
      }
    }
  }

  /**
   * Toggles end date field based on "currently working" checkbox
   */
  toggleCurrent(event) {
    if (this.hasEndDateTarget) {
      if (event.target.checked) {
        this.endDateTarget.value = ""
        this.endDateTarget.disabled = true
        this.endDateTarget.classList.add("opacity-50", "cursor-not-allowed")
      } else {
        this.endDateTarget.disabled = false
        this.endDateTarget.classList.remove("opacity-50", "cursor-not-allowed")
      }
    }
  }

  /**
   * Opens edit modal/form for an experience
   * For now, this could redirect or show an inline form
   */
  editExperience(event) {
    const experienceId = event.currentTarget.dataset.experienceId
    // TODO: Implement inline editing or modal
    // For now, we can use a simple approach
    console.log("Edit experience:", experienceId)
    
    // Option: Navigate to a dedicated edit page
    // window.location.href = `/settings?tab=work_experience&edit=${experienceId}`
    
    // Or: Show inline edit form
    alert("Inline editing coming soon. For now, delete and re-add to make changes.")
  }
}
