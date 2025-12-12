import { Controller } from "@hotwired/stimulus"

/**
 * Controller for auto-refreshing resume analysis status
 *
 * Polls the server to check analysis status and refreshes the page
 * when analysis is complete. Stops polling when analysis is no longer
 * in pending/processing state.
 *
 * @example
 *   <div data-controller="analysis-status"
 *        data-analysis-status-url-value="/resumes/1"
 *        data-analysis-status-status-value="processing"
 *        data-analysis-status-interval-value="5000">
 *   </div>
 */
export default class extends Controller {
  static values = {
    url: String,
    status: String,
    interval: { type: Number, default: 5000 }
  }

  connect() {
    // Only poll if status is pending or processing
    if (this.shouldPoll()) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  shouldPoll() {
    return this.statusValue === "pending" || this.statusValue === "processing"
  }

  startPolling() {
    this.poll()
    this.pollTimer = setInterval(() => this.poll(), this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) return

      const data = await response.json()

      // If status changed from pending/processing, refresh the page
      if (data.analysis_status !== this.statusValue) {
        if (data.analysis_status === "completed" || data.analysis_status === "failed") {
          // Refresh the page to show updated content
          window.location.reload()
        } else {
          // Update status value for continued polling
          this.statusValue = data.analysis_status
        }
      }
    } catch (error) {
      console.error("Error polling analysis status:", error)
    }
  }
}
