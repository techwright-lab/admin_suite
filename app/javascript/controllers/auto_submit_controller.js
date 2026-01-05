import { Controller } from "@hotwired/stimulus"

/**
 * AutoSubmitController
 * 
 * Automatically submits a form when inputs change, with debouncing and min-length support.
 * Preserves focus on the input element after Turbo page updates.
 * 
 * Example usage:
 * <form data-controller="auto-submit" data-auto-submit-delay-value="300" data-auto-submit-min-length-value="3">
 *   <input type="text" data-auto-submit-target="input" data-action="input->auto-submit#submit">
 *   <select data-action="change->auto-submit#submitNow">
 * </form>
 */
export default class extends Controller {
  static targets = ["input"]
  
  static values = {
    delay: { type: Number, default: 300 },
    minLength: { type: Number, default: 0 }
  }

  connect() {
    this.timeout = null
    
    // Restore focus if we were typing before page reload
    this.restoreFocus()
  }

  disconnect() {
    this.clearTimeout()
  }

  /**
   * Submits the form with debouncing and min-length check
   * @param {Event} event - The triggering event
   */
  submit(event) {
    this.clearTimeout()
    
    const input = event.target
    const value = input.value || ""
    const minLength = this.minLengthValue
    
    // Don't submit if below minimum length (unless empty for clearing)
    if (value.length > 0 && value.length < minLength) {
      return
    }

    // Store focus info for restoration after page reload
    this.saveFocusState(input)

    const delay = input.dataset.autoSubmitDelayValue 
      ? parseInt(input.dataset.autoSubmitDelayValue, 10) 
      : this.delayValue

    if (delay > 0) {
      this.timeout = setTimeout(() => {
        this.performSubmit()
      }, delay)
    } else {
      this.performSubmit()
    }
  }

  /**
   * Immediately submits the form (no debounce, no min-length check)
   */
  submitNow(event) {
    this.clearTimeout()
    
    if (event && event.target) {
      this.saveFocusState(event.target)
    }
    
    this.performSubmit()
  }

  /**
   * Performs the actual form submission
   */
  performSubmit() {
    // Use requestSubmit for Turbo compatibility
    if (this.element.requestSubmit) {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }

  /**
   * Saves focus state to sessionStorage for restoration after page reload
   * @param {HTMLElement} input - The input element
   */
  saveFocusState(input) {
    const inputId = input.id || input.name
    if (inputId) {
      const focusState = {
        inputId: inputId,
        cursorPosition: input.selectionStart,
        timestamp: Date.now()
      }
      sessionStorage.setItem('autoSubmitFocus', JSON.stringify(focusState))
    }
  }

  /**
   * Restores focus from sessionStorage after page reload
   */
  restoreFocus() {
    try {
      const stored = sessionStorage.getItem('autoSubmitFocus')
      if (!stored) return
      
      const focusState = JSON.parse(stored)
      
      // Only restore if recent (within 2 seconds)
      if (Date.now() - focusState.timestamp > 2000) {
        sessionStorage.removeItem('autoSubmitFocus')
        return
      }
      
      // Find the input by id or name
      let input = null
      if (this.hasInputTarget) {
        const target = this.inputTarget
        if (target.id === focusState.inputId || target.name === focusState.inputId) {
          input = target
        }
      }
      
      if (!input) {
        input = document.getElementById(focusState.inputId) || 
                document.querySelector(`[name="${focusState.inputId}"]`)
      }
      
      if (input && document.contains(input)) {
        // Use requestAnimationFrame to ensure DOM is ready
        requestAnimationFrame(() => {
          input.focus()
          
          // Restore cursor position at end of text
          if (input.value && input.setSelectionRange) {
            try {
              const pos = input.value.length
              input.setSelectionRange(pos, pos)
            } catch (e) {
              // Some input types don't support setSelectionRange
            }
          }
        })
      }
      
      // Clear the stored state
      sessionStorage.removeItem('autoSubmitFocus')
    } catch (e) {
      // Ignore errors
      sessionStorage.removeItem('autoSubmitFocus')
    }
  }

  /**
   * Clears any pending timeout
   */
  clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }
}
