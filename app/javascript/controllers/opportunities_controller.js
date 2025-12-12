import { Controller } from "@hotwired/stimulus"

// Manages the opportunities stacked cards UI
// Handles animations for apply/ignore actions and card transitions
export default class extends Controller {
  static targets = ["stack", "currentCard"]

  connect() {
    this.isAnimating = false
  }

  // Handle apply action with animation
  apply(event) {
    if (this.isAnimating) {
      event.preventDefault()
      return
    }
    
    this.animateCardOut("right")
  }

  // Handle ignore action with animation
  ignore(event) {
    if (this.isAnimating) {
      event.preventDefault()
      return
    }
    
    this.animateCardOut("left")
  }

  // Animate the current card out
  animateCardOut(direction) {
    if (!this.hasCurrentCardTarget) return
    
    this.isAnimating = true
    const card = this.currentCardTarget
    
    // Add animation classes
    card.style.transition = "transform 0.3s ease-out, opacity 0.3s ease-out"
    
    if (direction === "left") {
      card.style.transform = "translateX(-120%) rotate(-10deg)"
    } else {
      card.style.transform = "translateX(120%) rotate(10deg)"
    }
    card.style.opacity = "0"
    
    // Reset animation state after completion
    setTimeout(() => {
      this.isAnimating = false
    }, 350)
  }

  // Handle keyboard navigation
  keydown(event) {
    if (this.isAnimating) return
    
    switch (event.key) {
      case "ArrowLeft":
      case "Escape":
        // Trigger ignore
        this.triggerIgnore()
        break
      case "ArrowRight":
      case "Enter":
        // Trigger apply
        this.triggerApply()
        break
    }
  }

  // Programmatically trigger ignore
  triggerIgnore() {
    const ignoreButton = this.element.querySelector('[data-action*="ignore"]')
    if (ignoreButton) {
      ignoreButton.click()
    }
  }

  // Programmatically trigger apply
  triggerApply() {
    const applyButton = this.element.querySelector('[data-action*="apply"]')
    if (applyButton) {
      applyButton.click()
    }
  }

  // Touch/swipe support
  touchstart(event) {
    this.touchStartX = event.touches[0].clientX
    this.touchStartY = event.touches[0].clientY
  }

  touchmove(event) {
    if (!this.touchStartX || !this.hasCurrentCardTarget) return
    
    const currentX = event.touches[0].clientX
    const diffX = currentX - this.touchStartX
    
    // Add visual feedback during swipe
    const card = this.currentCardTarget
    const rotation = diffX * 0.05
    const opacity = Math.max(0.5, 1 - Math.abs(diffX) / 300)
    
    card.style.transform = `translateX(${diffX}px) rotate(${rotation}deg)`
    card.style.opacity = opacity
    card.style.transition = "none"
  }

  touchend(event) {
    if (!this.touchStartX || !this.hasCurrentCardTarget) return
    
    const currentX = event.changedTouches[0].clientX
    const diffX = currentX - this.touchStartX
    const card = this.currentCardTarget
    
    // Threshold for action (100px)
    if (Math.abs(diffX) > 100) {
      if (diffX < 0) {
        this.triggerIgnore()
      } else {
        this.triggerApply()
      }
    } else {
      // Reset card position
      card.style.transition = "transform 0.2s ease-out, opacity 0.2s ease-out"
      card.style.transform = ""
      card.style.opacity = ""
    }
    
    this.touchStartX = null
    this.touchStartY = null
  }
}

