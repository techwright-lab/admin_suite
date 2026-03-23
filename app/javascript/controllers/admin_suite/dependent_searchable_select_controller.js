import { Controller } from "@hotwired/stimulus"

/**
 * Dependent Searchable Select Controller (Admin Suite)
 *
 * Extends searchable-select behavior with parent-field filtering.
 * Options are filtered by `group` matching the parent field's current value.
 *
 * Usage:
 *   data-controller="admin-suite--dependent-searchable-select"
 *   data-admin-suite--dependent-searchable-select-all-options-value="<%= options.to_json %>"
 *   data-admin-suite--dependent-searchable-select-parent-selector-value="#parent_field_id"
 *
 * Each option in allOptions should have: { value, label, group }
 * The `group` field is matched against the parent field's value.
 */
export default class extends Controller {
  static targets = ["input", "search", "dropdown"]
  static values = {
    allOptions: { type: Array, default: [] },
    parentSelector: { type: String, default: "" },
  }

  connect() {
    this.isOpen = false
    this.selectedIndex = -1
    this.parentFilteredOptions = [...this.allOptionsValue]

    this.clickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutside)

    this.bindParent()
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutside)

    if (this._parentField && this._onParentChange) {
      this._parentField.removeEventListener("change", this._onParentChange)
    }
  }

  bindParent() {
    const selector = this.parentSelectorValue
    if (!selector) return

    this._parentField = document.querySelector(selector)
    if (!this._parentField) return

    this._onParentChange = this.onParentChange.bind(this)
    this._parentField.addEventListener("change", this._onParentChange)

    // Apply initial filter if parent already has a value
    if (this._parentField.value) {
      this.filterByParent(this._parentField.value)
    }
  }

  onParentChange() {
    const parentValue = this._parentField ? this._parentField.value : ""
    this.filterByParent(parentValue)

    // Clear current selection if it no longer belongs to the new parent group
    const currentValue = this.inputTarget.value
    if (currentValue) {
      const stillValid = this.parentFilteredOptions.some(
        (opt) => String(opt.value) === String(currentValue),
      )
      if (!stillValid) {
        this.inputTarget.value = ""
        this.searchTarget.value = ""
        this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
      }
    }

    if (this.isOpen) {
      this.renderDropdown()
    }
  }

  filterByParent(parentValue) {
    if (!parentValue) {
      this.parentFilteredOptions = [...this.allOptionsValue]
    } else {
      this.parentFilteredOptions = this.allOptionsValue.filter(
        (opt) => String(opt.group) === String(parentValue),
      )
    }
  }

  open() {
    this.isOpen = true
    this.filteredOptions = [...this.parentFilteredOptions]
    this.renderDropdown()
    this.dropdownTarget.classList.remove("hidden")
  }

  close() {
    this.isOpen = false
    this.dropdownTarget.classList.add("hidden")
    this.selectedIndex = -1
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  search() {
    const query = this.searchTarget.value.toLowerCase().trim()

    if (query) {
      this.filteredOptions = this.parentFilteredOptions.filter((opt) =>
        opt.label.toLowerCase().includes(query),
      )
    } else {
      this.filteredOptions = [...this.parentFilteredOptions]
    }

    this.renderDropdown()

    if (!this.isOpen) this.open()
  }

  select(event) {
    const btn = event.currentTarget
    const value = btn.dataset.value
    const label = btn.dataset.label

    this.inputTarget.value = value
    this.searchTarget.value = label
    this.close()
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  keydown(event) {
    const opts = this.filteredOptions || this.parentFilteredOptions

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        if (!this.isOpen) {
          this.filteredOptions = [...this.parentFilteredOptions]
          this.open()
          break
        }
        this.selectedIndex = Math.min(this.selectedIndex + 1, opts.length - 1)
        this.renderDropdown()
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
        this.renderDropdown()
        break
      case "Enter":
        event.preventDefault()
        if (this.selectedIndex >= 0 && opts[this.selectedIndex]) {
          const opt = opts[this.selectedIndex]
          this.inputTarget.value = opt.value
          this.searchTarget.value = opt.label
          this.close()
          this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
        }
        break
      case "Escape":
        this.close()
        break
    }
  }

  renderDropdown() {
    const opts = this.filteredOptions || this.parentFilteredOptions

    // Clear existing content using safe DOM manipulation (avoids innerHTML XSS risk)
    while (this.dropdownTarget.firstChild) {
      this.dropdownTarget.removeChild(this.dropdownTarget.firstChild)
    }

    if (!opts.length) {
      const empty = document.createElement("div")
      empty.className = "px-3 py-2 text-sm text-slate-400"
      empty.textContent = "No results found"
      this.dropdownTarget.appendChild(empty)
      return
    }

    opts.forEach((opt, index) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = [
        "block w-full text-left px-3 py-2 text-sm hover:bg-slate-100",
        index === this.selectedIndex ? "bg-slate-100" : "",
        "text-slate-700",
      ]
        .filter(Boolean)
        .join(" ")
      btn.dataset.action =
        "click->admin-suite--dependent-searchable-select#select"
      btn.dataset.value = this.escapeAttr(String(opt.value))
      btn.dataset.label = this.escapeAttr(String(opt.label))

      // Label text node
      btn.appendChild(document.createTextNode(opt.label))

      // Optional group badge
      if (opt.group) {
        const badge = document.createElement("span")
        badge.className =
          "ml-2 text-xs text-slate-400 font-normal"
        badge.textContent = opt.group
        btn.appendChild(badge)
      }

      this.dropdownTarget.appendChild(btn)
    })
  }

  // Escapes a string for use in HTML data attributes
  escapeAttr(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }
}
