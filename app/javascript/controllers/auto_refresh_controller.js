import { Controller } from "@hotwired/stimulus"

/**
 * Auto-refresh controller for polling endpoints via Turbo
 *
 * Usage:
 *   <div data-controller="auto-refresh"
 *        data-auto-refresh-url-value="/path/to/poll"
 *        data-auto-refresh-interval-value="3000">
 *   </div>
 */
export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 3000 }
  }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    if (this.hasUrlValue) {
      this.poll()
    }
  }

  stopPolling() {
    if (this.pollTimeout) {
      clearTimeout(this.pollTimeout)
      this.pollTimeout = null
    }
  }

  poll() {
    this.pollTimeout = setTimeout(() => {
      this.refresh()
    }, this.intervalValue)
  }

  async refresh() {
    if (!this.hasUrlValue) return

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }

      // Continue polling unless element was removed (generation complete)
      if (this.element.isConnected) {
        this.poll()
      }
    } catch (error) {
      console.error("Auto-refresh error:", error)
      // Retry after interval even on error
      if (this.element.isConnected) {
        this.poll()
      }
    }
  }
}
