import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dynamic-sections"
// Manages dynamic custom sections in job listing forms
export default class extends Controller {
  static targets = ["container", "section"]

  add(event) {
    event.preventDefault()
    
    const template = this.sectionTemplate()
    this.containerTarget.insertAdjacentHTML("beforeend", template)
  }

  remove(event) {
    event.preventDefault()
    
    const section = event.target.closest('[data-dynamic-sections-target="section"]')
    if (section) {
      section.remove()
    }
  }

  sectionTemplate() {
    return `
      <div data-dynamic-sections-target="section" class="flex gap-2">
        <input type="text" 
               name="job_listing[custom_sections_keys][]" 
               placeholder="Section Name"
               class="flex-1 rounded-lg border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-sm focus:border-primary-500 focus:ring-primary-500">
        <textarea name="job_listing[custom_sections_values][]" 
                  rows="2" 
                  placeholder="Section Content"
                  class="flex-[2] rounded-lg border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-sm focus:border-primary-500 focus:ring-primary-500"></textarea>
        <button type="button"
                data-action="click->dynamic-sections#remove"
                class="flex-shrink-0 text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
          </svg>
        </button>
      </div>
    `
  }
}

