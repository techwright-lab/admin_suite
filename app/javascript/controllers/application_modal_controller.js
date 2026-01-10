import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="application-modal"
// Handles tab switching, quick apply form submission, and manual entry form submission
// 
// Targets:
//   - quickApplyTab/manualEntryTab: Tab buttons for switching views
//   - quickApplyPanel/manualEntryPanel: Content panels for each mode
//   - quickApplyForm: The quick apply URL form
//   - urlInput: The URL input field
//   - loadingIndicator: Quick apply loading state
//   - errorMessage/successMessage: Feedback messages
//   - quickApplyButton: Submit button for quick apply
//   - manualLoadingIndicator: Manual entry loading state
//   - manualFormActions: Manual entry form action buttons
//   - manualSubmitButton: Submit button for manual entry
export default class extends Controller {
  static targets = [
    "quickApplyTab",
    "manualEntryTab",
    "quickApplyPanel",
    "manualEntryPanel",
    "quickApplyForm",
    "quickApplyFormContent",
    "urlInput",
    "loadingIndicator",
    "loadingStep1",
    "loadingStep2",
    "loadingStep3",
    "errorMessage",
    "successMessage",
    "quickApplyButton",
    "manualLoadingIndicator",
    "manualFormActions",
    "manualSubmitButton",
    "linkedinWarning"
  ]

  // Limited extraction job boards that show warnings
  static LIMITED_SOURCES = ["linkedin.com", "indeed.com", "glassdoor.com"]

  connect() {
    // Default to Quick Apply tab
    this.switchToQuickApply()
  }

  // Checks if the entered URL is from a limited extraction source (LinkedIn, Indeed, etc.)
  // and shows an appropriate warning
  checkUrlSource(event) {
    const url = event.target.value.toLowerCase()
    
    if (!this.hasLinkedinWarningTarget) return

    const isLimitedSource = this.constructor.LIMITED_SOURCES.some(source => url.includes(source))
    
    if (isLimitedSource) {
      this.linkedinWarningTarget.classList.remove("hidden")
    } else {
      this.linkedinWarningTarget.classList.add("hidden")
    }
  }

  switchToQuickApply(event) {
    if (event) {
      event.preventDefault()
    }

    // Update tab styles
    this.quickApplyTabTarget.classList.add(
      "border-primary-500",
      "text-primary-600",
      "dark:text-primary-400"
    )
    this.quickApplyTabTarget.classList.remove(
      "border-transparent",
      "text-gray-500",
      "hover:text-gray-700",
      "hover:border-gray-300",
      "dark:text-gray-400",
      "dark:hover:text-gray-300"
    )

    this.manualEntryTabTarget.classList.remove(
      "border-primary-500",
      "text-primary-600",
      "dark:text-primary-400"
    )
    this.manualEntryTabTarget.classList.add(
      "border-transparent",
      "text-gray-500",
      "hover:text-gray-700",
      "hover:border-gray-300",
      "dark:text-gray-400",
      "dark:hover:text-gray-300"
    )

    // Show/hide panels
    this.quickApplyPanelTarget.classList.remove("hidden")
    this.manualEntryPanelTarget.classList.add("hidden")

    // Clear any previous messages
    this.hideMessages()
  }

  switchToManualEntry(event) {
    if (event) {
      event.preventDefault()
    }

    // Update tab styles
    this.manualEntryTabTarget.classList.add(
      "border-primary-500",
      "text-primary-600",
      "dark:text-primary-400"
    )
    this.manualEntryTabTarget.classList.remove(
      "border-transparent",
      "text-gray-500",
      "hover:text-gray-700",
      "hover:border-gray-300",
      "dark:text-gray-400",
      "dark:hover:text-gray-300"
    )

    this.quickApplyTabTarget.classList.remove(
      "border-primary-500",
      "text-primary-600",
      "dark:text-primary-400"
    )
    this.quickApplyTabTarget.classList.add(
      "border-transparent",
      "text-gray-500",
      "hover:text-gray-700",
      "hover:border-gray-300",
      "dark:text-gray-400",
      "dark:hover:text-gray-300"
    )

    // Show/hide panels
    this.manualEntryPanelTarget.classList.remove("hidden")
    this.quickApplyPanelTarget.classList.add("hidden")

    // Clear any previous messages
    this.hideMessages()
  }

  async handleQuickApply(event) {
    event.preventDefault()

    const url = this.urlInputTarget.value.trim()

    if (!url) {
      this.showError("Please enter a job listing URL")
      return
    }

    // Validate URL format
    try {
      new URL(url)
    } catch {
      this.showError("Please enter a valid URL")
      return
    }

    // Show loading state immediately
    this.showLoading()
    this.quickApplyButtonTarget.disabled = true

    // Start progress animation
    this.startLoadingProgress()

    try {
      const response = await fetch("/applications/quick_apply", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "application/json"
        },
        body: JSON.stringify({ url: url })
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccess(
          `Redirecting to ${data.application.company_name} - ${data.application.job_role_title}...`
        )

        // Redirect after a short delay
        setTimeout(() => {
          window.location.href = data.application.url
        }, 1500)
      } else {
        this.showError(data.error || "Failed to create application. Please try again.")
        this.hideLoading()
        this.quickApplyButtonTarget.disabled = false
      }
    } catch (error) {
      console.error("Quick apply error:", error)
      this.showError("An error occurred. Please try again or use manual entry.")
      this.hideLoading()
      this.quickApplyButtonTarget.disabled = false
    }
  }

  startLoadingProgress() {
    // Animate loading steps to show progress
    this.loadingStepIndex = 0
    this.loadingInterval = setInterval(() => {
      this.loadingStepIndex++
      
      if (this.loadingStepIndex === 1 && this.hasLoadingStep2Target) {
        this.loadingStep1Target.classList.add("opacity-50")
        this.loadingStep1Target.querySelector("svg")?.classList.remove("animate-pulse")
        this.loadingStep2Target.classList.remove("opacity-50")
        this.loadingStep2Target.querySelector(".bg-gray-400")?.classList.add("bg-primary-600", "animate-pulse")
        this.loadingStep2Target.querySelector(".bg-gray-400")?.classList.remove("bg-gray-400")
      } else if (this.loadingStepIndex === 2 && this.hasLoadingStep3Target) {
        this.loadingStep2Target.classList.add("opacity-50")
        this.loadingStep3Target.classList.remove("opacity-50")
        this.loadingStep3Target.querySelector(".bg-gray-400")?.classList.add("bg-primary-600", "animate-pulse")
        this.loadingStep3Target.querySelector(".bg-gray-400")?.classList.remove("bg-gray-400")
      } else if (this.loadingStepIndex >= 3) {
        clearInterval(this.loadingInterval)
      }
    }, 3000)
  }

  showLoading() {
    // Hide the form content
    if (this.hasQuickApplyFormContentTarget) {
      this.quickApplyFormContentTarget.classList.add("hidden")
    }
    // Show the loading indicator
    this.loadingIndicatorTarget.classList.remove("hidden")
    // Hide success message
    this.successMessageTarget.classList.add("hidden")
  }

  hideLoading() {
    // Clear any loading interval
    if (this.loadingInterval) {
      clearInterval(this.loadingInterval)
    }
    // Show the form content
    if (this.hasQuickApplyFormContentTarget) {
      this.quickApplyFormContentTarget.classList.remove("hidden")
    }
    // Hide the loading indicator
    this.loadingIndicatorTarget.classList.add("hidden")
    // Reset loading steps
    this.resetLoadingSteps()
  }

  resetLoadingSteps() {
    if (this.hasLoadingStep1Target) {
      this.loadingStep1Target.classList.remove("opacity-50")
      const svg = this.loadingStep1Target.querySelector("svg")
      if (svg) svg.classList.add("animate-pulse")
    }
    if (this.hasLoadingStep2Target) {
      this.loadingStep2Target.classList.add("opacity-50")
    }
    if (this.hasLoadingStep3Target) {
      this.loadingStep3Target.classList.add("opacity-50")
    }
  }

  showError(message) {
    // Show form again with error
    this.hideLoading()
    this.errorMessageTarget.querySelector("p").textContent = message
    this.errorMessageTarget.classList.remove("hidden")
    this.successMessageTarget.classList.add("hidden")
  }

  showSuccess(message) {
    // Keep loading hidden, show success
    this.loadingIndicatorTarget.classList.add("hidden")
    if (this.hasQuickApplyFormContentTarget) {
      this.quickApplyFormContentTarget.classList.add("hidden")
    }
    this.successMessageTarget.querySelector("p").textContent = message
    this.successMessageTarget.classList.remove("hidden")
    this.errorMessageTarget.classList.add("hidden")
  }

  hideMessages() {
    this.errorMessageTarget.classList.add("hidden")
    this.successMessageTarget.classList.add("hidden")
    if (this.hasLinkedinWarningTarget) {
      this.linkedinWarningTarget.classList.add("hidden")
    }
  }

  // Handles manual entry form submission - shows loading state
  handleManualSubmit(event) {
    // Don't prevent default - let the form submit normally
    // Just show the loading indicator
    this.showManualLoading()
  }

  showManualLoading() {
    if (this.hasManualLoadingIndicatorTarget) {
      this.manualLoadingIndicatorTarget.classList.remove("hidden")
    }
    if (this.hasManualFormActionsTarget) {
      this.manualFormActionsTarget.classList.add("hidden")
    }
    if (this.hasManualSubmitButtonTarget) {
      this.manualSubmitButtonTarget.disabled = true
    }
  }

  hideManualLoading() {
    if (this.hasManualLoadingIndicatorTarget) {
      this.manualLoadingIndicatorTarget.classList.add("hidden")
    }
    if (this.hasManualFormActionsTarget) {
      this.manualFormActionsTarget.classList.remove("hidden")
    }
    if (this.hasManualSubmitButtonTarget) {
      this.manualSubmitButtonTarget.disabled = false
    }
  }
}

