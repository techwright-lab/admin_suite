import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="autocomplete"
export default class extends Controller {
  static targets = ["input", "hiddenInput", "dropdown", "results"]
  static values = {
    url: String,
    createUrl: String,
    modalTarget: String,
    kind: String,
    minChars: { type: Number, default: 2 },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
    this.selectedId = null
    this.selectedName = null
    
    // Listen for form submission to auto-create if needed
    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("submit", this.handleFormSubmit.bind(this))
    }
    
    // Also handle blur to auto-create if user leaves field with a value
    this.inputTarget.addEventListener("blur", this.handleBlur.bind(this))
  }

  disconnect() {
    const form = this.element.closest("form")
    if (form) {
      form.removeEventListener("submit", this.handleFormSubmit.bind(this))
    }
    this.inputTarget.removeEventListener("blur", this.handleBlur.bind(this))
  }

  // Search with debounce
  search(event) {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    // Clear hidden input if user is typing
    if (this.hiddenInputTarget.value) {
      this.hiddenInputTarget.value = ""
    }

    if (query.length < this.minCharsValue) {
      this.hideDropdown()
      return
    }

    this.timeout = setTimeout(() => {
      this.fetchResults(query)
    }, this.debounceValue)
  }

  // Fetch results from API
  async fetchResults(query) {
    try {
      const url = `${this.urlValue}?q=${encodeURIComponent(query)}`
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json"
        }
      })
      
      if (!response.ok) throw new Error("Network response was not ok")
      
      const data = await response.json()
      this.displayResults(data, query)
    } catch (error) {
      console.error("Autocomplete error:", error)
      this.showError("Failed to load results")
    }
  }

  // Display results in dropdown
  displayResults(results, query) {
    this.resultsTarget.innerHTML = ""

    if (results.length === 0) {
      // Show message that it will be created automatically
      const noResults = document.createElement("div")
      noResults.className = "px-4 py-3 text-sm text-gray-500 dark:text-gray-400"
      noResults.textContent = `No results found. "${this.escapeHtml(query)}" will be created automatically.`
      this.resultsTarget.appendChild(noResults)
    } else {
      // Show existing results
      results.forEach(result => {
        const item = this.createResultItem(result)
        this.resultsTarget.appendChild(item)
      })
    }

    this.showDropdown()
  }

  // Create result item element
  createResultItem(result) {
    const div = document.createElement("div")
    div.className = "px-4 py-3 cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
    div.dataset.id = result.id
    div.dataset.name = result.name || result.title
    
    const name = result.name || result.title
    const subtitle = result.website || result.category
    
    div.innerHTML = `
      <div class="font-medium text-gray-900 dark:text-white">${this.escapeHtml(name)}</div>
      ${subtitle ? `<div class="text-sm text-gray-500 dark:text-gray-400">${this.escapeHtml(subtitle)}</div>` : ''}
    `
    
    div.addEventListener("mousedown", (e) => {
      e.preventDefault() // Prevent input blur
      this.selectItem(result)
    })
    
    return div
  }

  // Select existing item
  selectItem(item) {
    this.selectedId = item.id
    this.selectedName = item.name || item.title
    
    this.inputTarget.value = this.selectedName
    this.hiddenInputTarget.value = this.selectedId
    
    this.hideDropdown()
    
    // Dispatch custom event
    this.element.dispatchEvent(new CustomEvent("autocomplete:selected", {
      detail: { id: this.selectedId, name: this.selectedName },
      bubbles: true
    }))
  }

  // Handle form submission - auto-create if needed
  async handleFormSubmit(event) {
    const inputValue = this.inputTarget.value.trim()
    
    // If no ID is set but there's a value, try to create it
    if (!this.hiddenInputTarget.value && inputValue.length > 0) {
      event.preventDefault()
      await this.autoCreate(inputValue, event)
    }
  }

  // Handle blur - auto-create if needed (only if user typed something meaningful)
  async handleBlur(event) {
    const inputValue = this.inputTarget.value.trim()
    
    // Only auto-create if:
    // 1. No ID is set
    // 2. There's a meaningful value (at least 2 chars)
    // 3. User hasn't just clicked on a dropdown item (which would have set the ID)
    if (!this.hiddenInputTarget.value && inputValue.length >= this.minCharsValue) {
      // Small delay to allow dropdown click to register first
      setTimeout(async () => {
        // Double-check ID wasn't set by a click
        if (!this.hiddenInputTarget.value && this.inputTarget.value.trim().length >= this.minCharsValue) {
          await this.autoCreate(this.inputTarget.value.trim())
        }
      }, 100)
    }
  }

  // Automatically create company/job role if it doesn't exist
  async autoCreate(name, submitEvent = null) {
    try {
      // Show loading state
      this.inputTarget.disabled = true
      const originalValue = this.inputTarget.value
      
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({
          name: name,
          title: name,  // For job roles
          kind: this.hasKindValue ? this.kindValue : undefined
        })
      })
      
      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.errors || "Failed to create")
      }
      
      const data = await response.json()
      
      // Set the created ID
      this.hiddenInputTarget.value = data.id
      this.selectedId = data.id
      this.selectedName = data.name || data.title
      
      // Update input with the created name (in case it was normalized)
      this.inputTarget.value = this.selectedName
      
      // Re-enable input
      this.inputTarget.disabled = false
      
      // If this was triggered by form submit, submit the form now
      if (submitEvent) {
        const form = this.element.closest("form")
        if (form) {
          // Create a new submit event and dispatch it
          const submitForm = () => {
            // Use requestSubmit to trigger validation
            if (form.requestSubmit) {
              form.requestSubmit()
            } else {
              form.submit()
            }
          }
          // Small delay to ensure hidden input is set
          setTimeout(submitForm, 50)
        }
      }
      
      // Dispatch event
      this.element.dispatchEvent(new CustomEvent("autocomplete:created", {
        detail: { id: this.selectedId, name: this.selectedName },
        bubbles: true
      }))
      
    } catch (error) {
      console.error("Auto-create error:", error)
      this.inputTarget.disabled = false
      this.showError(`Failed to create: ${error.message}`)
    }
  }

  // Show dropdown
  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }

  // Hide dropdown
  hideDropdown() {
    setTimeout(() => {
      this.dropdownTarget.classList.add("hidden")
    }, 200)
  }

  // Handle focus
  handleFocus() {
    if (this.inputTarget.value.trim().length >= this.minCharsValue) {
      this.fetchResults(this.inputTarget.value.trim())
    }
  }

  // Clear selection
  clear() {
    this.inputTarget.value = ""
    this.hiddenInputTarget.value = ""
    this.selectedId = null
    this.selectedName = null
    this.hideDropdown()
  }

  // Show error message
  showError(message) {
    this.resultsTarget.innerHTML = `
      <div class="px-4 py-3 text-sm text-red-600 dark:text-red-400">
        ${this.escapeHtml(message)}
      </div>
    `
    this.showDropdown()
  }

  // Utility: Escape HTML
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Utility: Generate unique ID
  generateId() {
    return `autocomplete-${Math.random().toString(36).substr(2, 9)}`
  }
}

