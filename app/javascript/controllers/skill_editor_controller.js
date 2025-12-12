import { Controller } from "@hotwired/stimulus"

// Controller for editing skill proficiency levels
// Handles inline skill level updates with optimistic UI
export default class extends Controller {
  static targets = ["levelButtons"]
  static values = {
    url: String
  }

  connect() {
    this.currentLevel = this.getCurrentLevel()
  }

  // Sets the user's proficiency level for this skill
  setLevel(event) {
    const level = parseInt(event.currentTarget.dataset.level, 10)
    if (isNaN(level) || level < 1 || level > 5) return

    // Optimistic UI update
    this.updateButtonStyles(level)
    
    // Send update to server
    this.saveLevel(level)
  }

  async saveLevel(level) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          resume_skill: { user_level: level }
        })
      })

      if (!response.ok) {
        // Revert on error
        this.updateButtonStyles(this.currentLevel)
        console.error("Failed to update skill level")
        return
      }

      const data = await response.json()
      if (data.success) {
        this.currentLevel = level
        this.showConfirmedStatus()
      }
    } catch (error) {
      // Revert on network error
      this.updateButtonStyles(this.currentLevel)
      console.error("Failed to update skill level:", error)
    }
  }

  updateButtonStyles(selectedLevel) {
    const buttons = this.levelButtonsTarget.querySelectorAll("button")
    
    buttons.forEach((button, index) => {
      const level = index + 1
      button.classList.remove(
        "bg-primary-600", "border-primary-600", "text-white",
        "bg-gray-200", "border-gray-300", "text-gray-600",
        "bg-white", "border-gray-300", "text-gray-400",
        "dark:bg-dark-700", "dark:border-gray-600", "dark:text-gray-400",
        "dark:bg-dark-800"
      )
      
      if (level === selectedLevel) {
        button.classList.add("bg-primary-600", "border-primary-600", "text-white")
      } else {
        button.classList.add(
          "bg-white", "dark:bg-dark-800",
          "border-gray-300", "dark:border-gray-600",
          "text-gray-400",
          "hover:border-primary-400", "hover:text-primary-600"
        )
      }
    })
  }

  showConfirmedStatus() {
    // Update the status text below the buttons
    const statusDiv = this.element.querySelector(".text-xs.text-center")
    if (statusDiv) {
      statusDiv.textContent = "Confirmed"
      statusDiv.classList.remove("text-gray-400")
      statusDiv.classList.add("text-green-600", "dark:text-green-400")
    }
  }

  getCurrentLevel() {
    const activeButton = this.levelButtonsTarget.querySelector(
      "button.bg-primary-600"
    )
    if (activeButton) {
      return parseInt(activeButton.dataset.level, 10)
    }
    return null
  }
}
