import { Controller } from "@hotwired/stimulus"

// Manages bulk selection with checkboxes for admin tables
export default class extends Controller {
  static targets = ["checkbox", "selectAll", "actionBar", "count", "approveIds", "enqueueIds"]

  connect() {
    this.updateUI()
  }

  toggle(event) {
    this.updateUI()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })
    this.updateUI()
  }

  clearAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
    }
    this.updateUI()
  }

  updateUI() {
    const selected = this.selectedIds
    const count = selected.length

    // Update count display
    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }

    // Show/hide action bar
    if (this.hasActionBarTarget) {
      if (count > 0) {
        this.actionBarTarget.classList.remove("hidden")
      } else {
        this.actionBarTarget.classList.add("hidden")
      }
    }

    // Update hidden form fields
    const idsString = selected.join(",")
    if (this.hasApproveIdsTarget) {
      this.approveIdsTarget.value = idsString
    }
    if (this.hasEnqueueIdsTarget) {
      this.enqueueIdsTarget.value = idsString
    }

    // Update "select all" checkbox state
    if (this.hasSelectAllTarget && this.checkboxTargets.length > 0) {
      const allChecked = this.checkboxTargets.every(cb => cb.checked)
      const someChecked = this.checkboxTargets.some(cb => cb.checked)
      this.selectAllTarget.checked = allChecked
      this.selectAllTarget.indeterminate = someChecked && !allChecked
    }
  }

  get selectedIds() {
    return this.checkboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
  }
}

