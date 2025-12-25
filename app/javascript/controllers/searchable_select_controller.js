import { Controller } from "@hotwired/stimulus"

/**
 * Searchable Select Controller
 * 
 * Provides a searchable dropdown for select fields with optional
 * AJAX-based searching and option creation.
 * 
 * Usage:
 *   <div data-controller="searchable-select"
 *        data-searchable-select-options-value='[{"value":"a","label":"A"}]'
 *        data-searchable-select-creatable-value="true">
 *     <input type="hidden" data-searchable-select-target="input">
 *     <input type="text" data-searchable-select-target="search">
 *     <div data-searchable-select-target="dropdown"></div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "search", "dropdown"]
  static values = {
    options: { type: Array, default: [] },
    creatable: { type: Boolean, default: false },
    searchUrl: { type: String, default: "" }
  }

  connect() {
    this.isOpen = false
    this.selectedIndex = -1
    this.filteredOptions = [...this.optionsValue]
    
    // Close dropdown when clicking outside
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
      // AJAX search
      this.fetchOptions(query)
    } else {
      // Client-side filtering
      this.filteredOptions = this.optionsValue.filter(opt => 
        opt.label.toLowerCase().includes(query)
      )
      
      // Add create option if enabled
      if (this.creatableValue && query && !this.filteredOptions.some(o => o.value === query)) {
        this.filteredOptions.push({ value: query, label: `Create "${query}"`, isNew: true })
      }
      
      this.renderDropdown()
    }
    
    if (!this.isOpen) this.open()
  }

  async fetchOptions(query) {
    try {
      const response = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`)
      const data = await response.json()
      this.filteredOptions = data.map(item => ({
        value: item.id || item.value,
        label: item.name || item.label
      }))
      
      if (this.creatableValue && query && !this.filteredOptions.some(o => o.value === query)) {
        this.filteredOptions.push({ value: query, label: `Create "${query}"`, isNew: true })
      }
      
      this.renderDropdown()
    } catch (error) {
      console.error("Search failed:", error)
    }
  }

  renderDropdown() {
    if (!this.filteredOptions.length) {
      this.dropdownTarget.innerHTML = `
        <div class="px-3 py-2 text-sm text-slate-400 dark:text-slate-500">No results found</div>
      `
      return
    }

    this.dropdownTarget.innerHTML = this.filteredOptions.map((opt, index) => `
      <button type="button" 
              class="block w-full text-left px-3 py-2 text-sm hover:bg-slate-100 dark:hover:bg-slate-700 ${index === this.selectedIndex ? 'bg-slate-100 dark:bg-slate-700' : ''} ${opt.isNew ? 'text-indigo-600 dark:text-indigo-400 font-medium' : 'text-slate-700 dark:text-slate-200'}"
              data-action="click->searchable-select#select"
              data-value="${opt.value}"
              data-label="${opt.label}">
        ${opt.label}
      </button>
    `).join('')
  }

  select(event) {
    const value = event.currentTarget.dataset.value
    const label = event.currentTarget.dataset.label.replace(/^Create "/, '').replace(/"$/, '')
    
    this.inputTarget.value = value
    this.searchTarget.value = label
    this.close()
  }

  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, this.filteredOptions.length - 1)
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
          const opt = this.filteredOptions[this.selectedIndex]
          this.inputTarget.value = opt.value
          this.searchTarget.value = opt.label.replace(/^Create "/, '').replace(/"$/, '')
          this.close()
        }
        break
      case "Escape":
        this.close()
        break
    }
  }
}
