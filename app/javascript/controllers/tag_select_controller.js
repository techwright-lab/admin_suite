import { Controller } from "@hotwired/stimulus"

/**
 * Tag Select Controller
 * 
 * Provides a tag/multi-select input with inline tag creation.
 * Tags can be added by typing and pressing Enter or comma.
 * 
 * Usage:
 *   <div data-controller="tag-select"
 *        data-tag-select-creatable-value="true">
 *     <div data-tag-select-target="tags">
 *       <!-- Selected tags go here -->
 *     </div>
 *     <input data-tag-select-target="input">
 *     <div data-tag-select-target="dropdown">
 *       <!-- Suggestions go here -->
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["tags", "input", "dropdown", "placeholder"]
  static values = {
    creatable: { type: Boolean, default: true },
    suggestions: { type: Array, default: [] },
    fieldName: { type: String, default: "" }
  }

  connect() {
    this.selectedTags = this.getExistingTags()
    
    // Close dropdown when clicking outside
    this.clickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutside)
  }

  getExistingTags() {
    const tags = []
    this.tagsTarget.querySelectorAll("span[class*='bg-indigo']").forEach(el => {
      const hidden = el.querySelector("input[type='hidden']")
      if (hidden) tags.push(hidden.value)
    })
    return tags
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown()
    }
  }

  search() {
    const query = this.inputTarget.value.toLowerCase().trim()
    
    if (!query) {
      this.closeDropdown()
      return
    }

    if (this.hasDropdownTarget) {
      // Filter suggestions
      const buttons = this.dropdownTarget.querySelectorAll("button")
      let hasVisible = false
      
      buttons.forEach(btn => {
        const value = btn.dataset.value.toLowerCase()
        if (value.includes(query) && !this.selectedTags.includes(btn.dataset.value)) {
          btn.classList.remove("hidden")
          hasVisible = true
        } else {
          btn.classList.add("hidden")
        }
      })

      if (hasVisible) {
        this.dropdownTarget.classList.remove("hidden")
      } else if (this.creatableValue) {
        // Show create option
        this.dropdownTarget.classList.remove("hidden")
      } else {
        this.closeDropdown()
      }
    }
  }

  closeDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.add("hidden")
    }
  }

  keydown(event) {
    const value = this.inputTarget.value.trim()
    
    switch (event.key) {
      case "Enter":
      case ",":
        event.preventDefault()
        if (value && this.creatableValue) {
          this.addTag(value)
        }
        break
      case "Backspace":
        if (!value && this.selectedTags.length > 0) {
          // Remove last tag
          this.removeLastTag()
        }
        break
      case "Escape":
        this.closeDropdown()
        break
    }
  }

  select(event) {
    event.preventDefault()
    const value = event.currentTarget.dataset.value
    this.addTag(value)
    this.closeDropdown()
  }

  addTag(value) {
    if (this.selectedTags.includes(value)) return
    
    this.selectedTags.push(value)
    
    // Create tag element
    const tagEl = document.createElement("span")
    tagEl.className = "inline-flex items-center gap-1 px-2 py-1 bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 rounded text-sm"
    tagEl.innerHTML = `
      ${this.escapeHtml(value)}
      <input type="hidden" name="${this.getFieldName()}" value="${this.escapeHtml(value)}">
      <button type="button" class="text-indigo-500 hover:text-indigo-700 font-bold" data-action="tag-select#remove">×</button>
    `
    
    // Insert before the input
    this.inputTarget.parentNode.insertBefore(tagEl, this.inputTarget)
    
    // Clear input
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }

  remove(event) {
    event.preventDefault()
    const tagEl = event.currentTarget.closest("span")
    const hidden = tagEl.querySelector("input[type='hidden']")
    
    if (hidden) {
      const index = this.selectedTags.indexOf(hidden.value)
      if (index > -1) this.selectedTags.splice(index, 1)
    }
    
    tagEl.remove()
  }

  removeLastTag() {
    const tags = this.tagsTarget.querySelectorAll("span[class*='bg-indigo']")
    if (tags.length > 0) {
      const lastTag = tags[tags.length - 1]
      const hidden = lastTag.querySelector("input[type='hidden']")
      
      if (hidden) {
        const index = this.selectedTags.indexOf(hidden.value)
        if (index > -1) this.selectedTags.splice(index, 1)
      }
      
      lastTag.remove()
    }
  }

  getFieldName() {
    // Use the configured field name if available
    if (this.fieldNameValue) return this.fieldNameValue
    
    // Find existing hidden inputs to get the field name
    const existing = this.tagsTarget.querySelector("input[type='hidden']:not([data-tag-select-target='placeholder'])")
    if (existing && existing.name) return existing.name
    
    // Check placeholder
    if (this.hasPlaceholderTarget && this.placeholderTarget.name) {
      return this.placeholderTarget.name
    }
    
    // Look for the parent form to determine the resource name
    const form = this.element.closest("form")
    if (form) {
      // Try to find any hidden input in the form that has a param key pattern
      const anyHidden = form.querySelector("input[type='hidden'][name*='[']")
      if (anyHidden) {
        const match = anyHidden.name.match(/^([^\[]+)\[/)
        if (match) {
          return `${match[1]}[tag_list]`
        }
      }
    }
    
    // Fallback
    return "tag_list"
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

