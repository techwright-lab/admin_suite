import { Controller } from "@hotwired/stimulus"

/**
 * Searchable Select Controller (Admin Suite)
 *
 * Provides a searchable dropdown for select fields with optional AJAX search.
 */
export default class extends Controller {
  static targets = ["input", "search", "dropdown"]
  static values = {
    options: { type: Array, default: [] },
    creatable: { type: Boolean, default: false },
    searchUrl: { type: String, default: "" },
    createUrl: { type: String, default: "" },
  }

  connect() {
    this.isOpen = false
    this.selectedIndex = -1
    this.filteredOptions = [...this.optionsValue]

    this.clickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutside)
  }

  open() {
    this.isOpen = true
    this.filteredOptions = [...this.optionsValue]
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

    if (this.searchUrlValue) {
      this.fetchOptions(query)
    } else {
      this.filteredOptions = this.optionsValue.filter((opt) =>
        opt.label.toLowerCase().includes(query),
      )

      if (this.creatableValue && query && !this.hasExactOptionMatch(query)) {
        this.filteredOptions.push(this.buildCreateOption(query))
      }

      this.renderDropdown()
    }

    if (!this.isOpen) this.open()
  }

  async fetchOptions(query) {
    try {
      const response = await fetch(
        `${this.searchUrlValue}?q=${encodeURIComponent(query)}`,
      )
      const data = await response.json()
      this.filteredOptions = data.map((item) => ({
        value: item.id || item.value,
        label: item.name || item.title || item.label,
      }))

      if (this.creatableValue && query && !this.hasExactOptionMatch(query)) {
        this.filteredOptions.push(this.buildCreateOption(query))
      }

      this.renderDropdown()
    } catch (error) {
      console.error("Search failed:", error)
    }
  }

  renderDropdown() {
    if (!this.filteredOptions.length) {
      this.dropdownTarget.innerHTML = `
        <div class="px-3 py-2 text-sm text-slate-400">No results found</div>
      `
      return
    }

    this.dropdownTarget.innerHTML = this.filteredOptions
      .map(
        (opt, index) => `
      <button type="button"
              class="block w-full text-left px-3 py-2 text-sm hover:bg-slate-100 ${index === this.selectedIndex ? "bg-slate-100" : ""} ${opt.isNew ? "text-indigo-600 font-medium" : "text-slate-700"}"
              data-action="click->admin-suite--searchable-select#select"
              data-value="${opt.value}"
              data-label="${opt.label}"
              data-create-label="${opt.createLabel || ""}"
              data-is-new="${opt.isNew ? "true" : "false"}">
        ${opt.label}
      </button>
    `,
      )
      .join("")
  }

  async select(event) {
    const option = this.optionFromElement(event.currentTarget)
    await this.applyOption(option)
  }

  async keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectedIndex = Math.min(
          this.selectedIndex + 1,
          this.filteredOptions.length - 1,
        )
        this.renderDropdown()
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
        this.renderDropdown()
        break
      case "Enter":
        event.preventDefault()
        if (this.selectedIndex >= 0 && this.filteredOptions[this.selectedIndex]) {
          const option = this.filteredOptions[this.selectedIndex]
          await this.applyOption(option)
        }
        break
      case "Escape":
        this.close()
        break
    }
  }

  hasExactOptionMatch(query) {
    return this.filteredOptions.some((opt) => {
      const value = String(opt.value || "").toLowerCase().trim()
      const label = String(opt.label || "").toLowerCase().trim()
      return value === query || label === query
    })
  }

  buildCreateOption(query) {
    return {
      value: query,
      label: `Create "${query}"`,
      createLabel: query,
      isNew: true,
    }
  }

  optionFromElement(element) {
    const isNew = element.dataset.isNew === "true"
    return {
      value: element.dataset.value,
      label: isNew
        ? element.dataset.createLabel || element.dataset.label
        : element.dataset.label,
      isNew,
    }
  }

  async applyOption(option) {
    if (!option) return

    let value = option.value
    let label = option.label || ""

    if (option.isNew) {
      if (!this.createUrlValue) {
        this.showInlineError("Create URL is not configured for this field.")
        return
      }

      const created = await this.createOption(label)
      if (!created) return

      value = created.id
      label = created.name || created.title || label
    }

    this.inputTarget.value = value
    this.searchTarget.value = label
    this.close()
  }

  async createOption(label) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    this.searchTarget.disabled = true

    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
        },
        body: JSON.stringify({
          name: label,
          title: label,
        }),
      })

      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        const errors = Array.isArray(data?.errors) ? data.errors.join(", ") : null
        this.showInlineError(errors || "Could not create this option.")
        return null
      }

      if (!data?.id) {
        this.showInlineError("Create endpoint returned no id.")
        return null
      }

      return data
    } catch (error) {
      console.error("Create failed:", error)
      this.showInlineError("Could not create this option.")
      return null
    } finally {
      this.searchTarget.disabled = false
    }
  }

  showInlineError(message) {
    this.dropdownTarget.innerHTML = `
      <div class="px-3 py-2 text-sm text-red-600">${this.escapeHtml(message)}</div>
    `
    this.dropdownTarget.classList.remove("hidden")
    this.isOpen = true
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value
    return div.innerHTML
  }
}

