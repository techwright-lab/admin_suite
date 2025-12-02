import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  connect() {
    this.applyTheme()
  }

  toggle(event) {
    event.preventDefault()
    const currentTheme = localStorage.getItem("theme") || "system"
    
    let newTheme
    if (currentTheme === "light") {
      newTheme = "dark"
    } else if (currentTheme === "dark") {
      newTheme = "system"
    } else {
      newTheme = "light"
    }
    
    localStorage.setItem("theme", newTheme)
    this.applyTheme()
  }

  applyTheme() {
    const theme = localStorage.getItem("theme") || "system"
    const root = document.documentElement
    
    // Remove existing theme classes
    root.classList.remove("light", "dark")
    
    if (theme === "dark") {
      root.classList.add("dark")
    } else if (theme === "light") {
      root.classList.add("light")
    } else {
      // System preference
      if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
        root.classList.add("dark")
      } else {
        root.classList.add("light")
      }
    }
  }
}

