// Controller for radio button card selection UI
// Updates visual styling when radio buttons are selected
//
// Example usage:
// <div data-controller="radio-cards">
//   <label data-radio-cards-target="card">
//     <input type="radio" data-radio-cards-target="radio" data-action="change->radio-cards#update">
//     <svg data-radio-cards-target="check" class="hidden">...</svg>
//   </label>
// </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "radio", "check"]

  static classes = {
    selected: ["border-primary-500", "bg-primary-50", "dark:bg-primary-900/20"],
    unselected: ["border-gray-200", "dark:border-gray-600"]
  }

  connect() {
    // Initialize visual state based on current selection
    this.update()
  }

  update() {
    this.cardTargets.forEach((card, index) => {
      const radio = this.radioTargets[index]
      const check = this.checkTargets[index]
      
      if (radio && radio.checked) {
        // Apply selected styles
        card.classList.remove("border-gray-200", "dark:border-gray-600")
        card.classList.add("border-primary-500", "bg-primary-50", "dark:bg-primary-900/20")
        if (check) check.classList.remove("hidden")
      } else {
        // Apply unselected styles
        card.classList.remove("border-primary-500", "bg-primary-50", "dark:bg-primary-900/20")
        card.classList.add("border-gray-200", "dark:border-gray-600")
        if (check) check.classList.add("hidden")
      }
    })
  }
}

