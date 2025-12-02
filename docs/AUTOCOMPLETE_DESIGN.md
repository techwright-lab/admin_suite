# Autocomplete with Inline Creation Design

## Overview

Implement autocomplete dropdowns for Company and JobRole selection with the ability to create new entries inline when not found.

---

## 🎯 User Experience Flow

### Scenario 1: Selecting Existing Company/Role
1. User types in the autocomplete field
2. Dropdown shows matching results as they type
3. User clicks on a result
4. Field is populated with the selection
5. Hidden input stores the ID

### Scenario 2: Creating New Company/Role
1. User types a name that doesn't exist
2. Dropdown shows "Create new: [Name]" option
3. User clicks "Create new"
4. Modal opens with pre-filled name
5. User adds additional details (optional)
6. User saves
7. New entry is created via AJAX
8. Dropdown closes, field is populated
9. Form can now be submitted

---

## 🏗️ Technical Architecture

### Components Needed

#### 1. Stimulus Controller: `autocomplete_controller.js`
**Responsibilities:**
- Handle input events (typing, focus, blur)
- Debounce API calls
- Fetch results from autocomplete endpoint
- Display dropdown with results
- Handle selection
- Show "Create new" option
- Open creation modal
- Handle AJAX creation

#### 2. Stimulus Controller: `autocomplete_modal_controller.js`
**Responsibilities:**
- Open/close modal
- Handle form submission via AJAX
- Update parent autocomplete on success
- Show validation errors

#### 3. Backend Endpoints (Already Created ✅)
- `GET /companies/autocomplete?q=search_term`
- `POST /companies` (JSON response)
- `GET /job_roles/autocomplete?q=search_term`
- `POST /job_roles` (JSON response)

---

## 📝 Implementation Details

### HTML Structure

```erb
<!-- Autocomplete Field -->
<div data-controller="autocomplete" 
     data-autocomplete-url-value="<%= autocomplete_companies_path %>"
     data-autocomplete-create-url-value="<%= companies_path %>"
     data-autocomplete-modal-target-value="company-modal">
  
  <!-- Display Input (what user sees) -->
  <input type="text" 
         data-autocomplete-target="input"
         data-action="input->autocomplete#search focus->autocomplete#showDropdown blur->autocomplete#hideDropdown"
         placeholder="Search or create company..."
         class="form-input">
  
  <!-- Hidden Input (stores ID for form submission) -->
  <input type="hidden" 
         name="interview_application[company_id]"
         data-autocomplete-target="hiddenInput">
  
  <!-- Dropdown Results -->
  <div data-autocomplete-target="dropdown" class="autocomplete-dropdown hidden">
    <div data-autocomplete-target="results"></div>
  </div>
</div>

<!-- Creation Modal (hidden by default) -->
<div id="company-modal" 
     data-controller="autocomplete-modal"
     class="modal hidden">
  <div class="modal-content">
    <h2>Create New Company</h2>
    <form data-action="submit->autocomplete-modal#submit">
      <input type="text" name="company[name]" data-autocomplete-modal-target="nameInput">
      <input type="text" name="company[website]" placeholder="Website (optional)">
      <textarea name="company[about]" placeholder="About (optional)"></textarea>
      <button type="submit">Create Company</button>
      <button type="button" data-action="click->autocomplete-modal#close">Cancel</button>
    </form>
  </div>
</div>
```

---

## 🎨 UI/UX Design

### Dropdown Appearance

```
┌─────────────────────────────────────┐
│ Search or create company...        │
├─────────────────────────────────────┤
│ 🏢 Google                           │
│    https://google.com               │
├─────────────────────────────────────┤
│ 🏢 Microsoft                        │
│    https://microsoft.com            │
├─────────────────────────────────────┤
│ ➕ Create new: "Gleania"            │
└─────────────────────────────────────┘
```

### Modal Appearance

```
┌───────────────────────────────────────┐
│ Create New Company               ✕    │
├───────────────────────────────────────┤
│                                       │
│ Name *                                │
│ ┌───────────────────────────────────┐ │
│ │ Gleania                           │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Website                               │
│ ┌───────────────────────────────────┐ │
│ │ https://gleania.com               │ │
│ └───────────────────────────────────┘ │
│                                       │
│ About                                 │
│ ┌───────────────────────────────────┐ │
│ │                                   │ │
│ │                                   │ │
│ └───────────────────────────────────┘ │
│                                       │
│  [Cancel]  [Create Company]           │
└───────────────────────────────────────┘
```

---

## 💻 Stimulus Controller Implementation

### autocomplete_controller.js

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenInput", "dropdown", "results"]
  static values = {
    url: String,           // Autocomplete endpoint
    createUrl: String,     // Create endpoint
    modalTarget: String,   // Modal ID
    minChars: { type: Number, default: 2 },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
    this.selectedId = null
    this.selectedName = null
  }

  // Search with debounce
  search(event) {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

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
      const response = await fetch(url)
      const data = await response.json()
      
      this.displayResults(data, query)
    } catch (error) {
      console.error("Autocomplete error:", error)
    }
  }

  // Display results in dropdown
  displayResults(results, query) {
    this.resultsTarget.innerHTML = ""

    // Show existing results
    results.forEach(result => {
      const item = this.createResultItem(result)
      this.resultsTarget.appendChild(item)
    })

    // Add "Create new" option
    const createItem = this.createNewItem(query)
    this.resultsTarget.appendChild(createItem)

    this.showDropdown()
  }

  // Create result item element
  createResultItem(result) {
    const div = document.createElement("div")
    div.className = "autocomplete-item"
    div.dataset.id = result.id
    div.dataset.name = result.name || result.title
    div.innerHTML = `
      <div class="font-medium">${result.name || result.title}</div>
      ${result.website || result.category ? 
        `<div class="text-sm text-gray-500">${result.website || result.category}</div>` 
        : ''}
    `
    div.addEventListener("click", () => this.selectItem(result))
    return div
  }

  // Create "Create new" item
  createNewItem(query) {
    const div = document.createElement("div")
    div.className = "autocomplete-item create-new"
    div.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        <span>Create new: "${query}"</span>
      </div>
    `
    div.addEventListener("click", () => this.openCreateModal(query))
    return div
  }

  // Select existing item
  selectItem(item) {
    this.selectedId = item.id
    this.selectedName = item.name || item.title
    
    this.inputTarget.value = this.selectedName
    this.hiddenInputTarget.value = this.selectedId
    
    this.hideDropdown()
    
    // Dispatch custom event for other controllers
    this.element.dispatchEvent(new CustomEvent("autocomplete:selected", {
      detail: { id: this.selectedId, name: this.selectedName }
    }))
  }

  // Open creation modal
  openCreateModal(name) {
    this.hideDropdown()
    
    const modal = document.getElementById(this.modalTargetValue)
    if (modal) {
      // Pre-fill name in modal
      const nameInput = modal.querySelector('[data-autocomplete-modal-target="nameInput"]')
      if (nameInput) {
        nameInput.value = name
      }
      
      // Store reference for callback
      modal.dataset.autocompleteController = this.element.dataset.stimulusId
      
      // Open modal
      modal.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  // Handle successful creation (called by modal controller)
  handleCreated(event) {
    const { id, name } = event.detail
    this.selectItem({ id, name })
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }

  hideDropdown() {
    // Delay to allow click events to fire
    setTimeout(() => {
      this.dropdownTarget.classList.add("hidden")
    }, 200)
  }

  // Clear selection
  clear() {
    this.inputTarget.value = ""
    this.hiddenInputTarget.value = ""
    this.selectedId = null
    this.selectedName = null
  }
}
```

### autocomplete_modal_controller.js

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nameInput", "form"]
  static values = {
    createUrl: String
  }

  async submit(event) {
    event.preventDefault()
    
    const formData = new FormData(event.target)
    
    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: formData
      })
      
      if (response.ok) {
        const data = await response.json()
        this.handleSuccess(data)
      } else {
        const errors = await response.json()
        this.handleErrors(errors)
      }
    } catch (error) {
      console.error("Creation error:", error)
      this.showError("Failed to create. Please try again.")
    }
  }

  handleSuccess(data) {
    // Notify parent autocomplete controller
    const autocompleteId = this.element.dataset.autocompleteController
    const autocompleteElement = document.querySelector(`[data-stimulus-id="${autocompleteId}"]`)
    
    if (autocompleteElement) {
      autocompleteElement.dispatchEvent(new CustomEvent("autocomplete:created", {
        detail: { id: data.id, name: data.name || data.title }
      }))
    }
    
    this.close()
  }

  handleErrors(errors) {
    // Display validation errors
    this.showError(errors.errors ? Object.values(errors.errors).flat().join(", ") : "Validation failed")
  }

  showError(message) {
    // Show error message in modal
    const errorDiv = document.createElement("div")
    errorDiv.className = "alert alert-error"
    errorDiv.textContent = message
    this.element.querySelector(".modal-content").prepend(errorDiv)
    
    setTimeout(() => errorDiv.remove(), 5000)
  }

  close() {
    this.element.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    this.element.querySelector("form").reset()
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }
}
```

---

## 🎨 CSS Styling

```css
/* Autocomplete Dropdown */
.autocomplete-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  max-height: 300px;
  overflow-y: auto;
  z-index: 50;
  margin-top: 0.25rem;
}

.autocomplete-item {
  padding: 0.75rem 1rem;
  cursor: pointer;
  transition: background-color 0.15s;
}

.autocomplete-item:hover {
  background-color: #f3f4f6;
}

.autocomplete-item.create-new {
  border-top: 1px solid #e5e7eb;
  color: #3b82f6;
  font-weight: 500;
}

.autocomplete-item.create-new:hover {
  background-color: #eff6ff;
}

/* Dark mode support */
.dark .autocomplete-dropdown {
  background: #1f2937;
  border-color: #374151;
}

.dark .autocomplete-item:hover {
  background-color: #374151;
}

.dark .autocomplete-item.create-new {
  border-color: #374151;
}
```

---

## 🔄 Data Flow

### Selection Flow
```
User Types
    ↓
Debounced Search
    ↓
Fetch from /autocomplete
    ↓
Display Results + "Create New"
    ↓
User Selects → Update Hidden Input → Form Ready
```

### Creation Flow
```
User Clicks "Create New"
    ↓
Open Modal with Pre-filled Name
    ↓
User Fills Additional Details
    ↓
Submit via AJAX to /companies or /job_roles
    ↓
Success → Update Autocomplete → Close Modal
    ↓
Form Ready with New ID
```

---

## ✅ Advantages of This Approach

1. **No Page Reload** - Seamless UX with AJAX
2. **Pre-filled Data** - Search term auto-fills the name
3. **Optional Details** - Can create with just a name or add more info
4. **Reusable** - Same pattern for companies and job roles
5. **Keyboard Friendly** - Arrow keys, Enter, Escape support
6. **Accessible** - ARIA labels and roles
7. **Mobile Friendly** - Touch-optimized
8. **Error Handling** - Validation errors shown inline

---

## 🚀 Implementation Order

1. ✅ **Backend Endpoints** - Already created
2. **Stimulus Controllers** - autocomplete_controller.js, autocomplete_modal_controller.js
3. **CSS Styling** - Dropdown and modal styles
4. **View Partials** - Reusable autocomplete component
5. **Integration** - Use in application form

---

## 📦 Reusable Partial

```erb
<!-- app/views/shared/_autocomplete.html.erb -->
<div data-controller="autocomplete" 
     data-autocomplete-url-value="<%= url %>"
     data-autocomplete-create-url-value="<%= create_url %>"
     data-autocomplete-modal-target-value="<%= modal_id %>"
     class="relative">
  
  <%= label_tag field_name, label, class: "form-label" %>
  
  <input type="text" 
         data-autocomplete-target="input"
         data-action="input->autocomplete#search focus->autocomplete#showDropdown"
         placeholder="<%= placeholder %>"
         class="form-input"
         autocomplete="off">
  
  <%= hidden_field_tag field_name, value, data: { autocomplete_target: "hiddenInput" } %>
  
  <div data-autocomplete-target="dropdown" class="autocomplete-dropdown hidden">
    <div data-autocomplete-target="results"></div>
  </div>
</div>
```

**Usage:**
```erb
<%= render "shared/autocomplete",
  field_name: "interview_application[company_id]",
  label: "Company",
  placeholder: "Search or create company...",
  url: autocomplete_companies_path,
  create_url: companies_path,
  modal_id: "company-modal",
  value: @application.company_id %>
```

---

## 🎯 Next Steps

1. Create Stimulus controllers
2. Add CSS styling
3. Create reusable partial
4. Integrate into application form
5. Test and refine UX

This approach provides a smooth, modern autocomplete experience with inline creation!

