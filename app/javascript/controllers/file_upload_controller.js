import { Controller } from "@hotwired/stimulus"

// Controller for file upload UI enhancements
// Shows filename preview when a file is selected
export default class extends Controller {
  static targets = ["input", "filename"]

  connect() {
    // Initialize drag and drop handlers on the parent drop zone
    const dropZone = this.element
    
    dropZone.addEventListener("dragover", this.handleDragOver.bind(this))
    dropZone.addEventListener("dragleave", this.handleDragLeave.bind(this))
    dropZone.addEventListener("drop", this.handleDrop.bind(this))
  }

  // Preview the selected file name
  preview(event) {
    const file = event.target.files[0]
    if (file) {
      this.showFileName(file)
    }
  }

  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.add("border-primary-500", "bg-primary-50", "dark:bg-primary-900/10")
  }

  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.remove("border-primary-500", "bg-primary-50", "dark:bg-primary-900/10")
  }

  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.remove("border-primary-500", "bg-primary-50", "dark:bg-primary-900/10")
    
    const files = event.dataTransfer.files
    if (files.length > 0) {
      const file = files[0]
      
      // Validate file type
      const allowedTypes = [
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "text/plain"
      ]
      
      if (!allowedTypes.includes(file.type)) {
        this.showError("Please upload a PDF, Word document, or text file")
        return
      }
      
      // Validate file size (10MB)
      if (file.size > 10 * 1024 * 1024) {
        this.showError("File is too large. Maximum size is 10MB")
        return
      }
      
      // Set the file on the input
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(file)
      this.inputTarget.files = dataTransfer.files
      
      this.showFileName(file)
    }
  }

  showFileName(file) {
    const fileName = file.name
    const fileSize = this.formatFileSize(file.size)
    
    this.filenameTarget.innerHTML = `
      <span class="font-medium text-gray-900 dark:text-white">${fileName}</span>
      <span class="text-gray-500 dark:text-gray-400">(${fileSize})</span>
    `
    this.filenameTarget.classList.remove("text-gray-500")
    this.filenameTarget.classList.add("text-green-600", "dark:text-green-400")
  }

  showError(message) {
    this.filenameTarget.innerHTML = `<span class="text-red-600 dark:text-red-400">${message}</span>`
  }

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }
}
