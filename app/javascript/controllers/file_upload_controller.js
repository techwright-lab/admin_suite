import { Controller } from "@hotwired/stimulus"

/**
 * File Upload Controller
 * 
 * Enhanced file upload with drag-drop, preview, validation, and progress indicator.
 * Supports image preview for image files and configurable validation rules.
 * 
 * Usage:
 *   <div data-controller="file-upload"
 *        data-file-upload-accept-value="image/*"
 *        data-file-upload-max-size-value="5242880"
 *        data-file-upload-preview-value="true">
 *     <input type="file" data-file-upload-target="input" data-action="change->file-upload#preview">
 *     <div data-file-upload-target="dropzone">Drop files here</div>
 *     <div data-file-upload-target="filename">No file selected</div>
 *     <img data-file-upload-target="imagePreview" class="hidden">
 *     <div data-file-upload-target="progress" class="hidden"></div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "filename", "dropzone", "imagePreview", "progress", "removeButton"]
  
  static values = {
    accept: { type: String, default: "" },
    maxSize: { type: Number, default: 10485760 }, // 10MB default
    preview: { type: Boolean, default: false },
    multiple: { type: Boolean, default: false },
    existingUrl: String
  }

  connect() {
    this.setupDropZone()
    
    // Show existing file preview if available
    if (this.existingUrlValue && this.hasImagePreviewTarget) {
      this.showExistingPreview()
    }
  }

  disconnect() {
    if (this.dropZoneElement) {
      this.dropZoneElement.removeEventListener("dragover", this.handleDragOver)
      this.dropZoneElement.removeEventListener("dragleave", this.handleDragLeave)
      this.dropZoneElement.removeEventListener("drop", this.handleDrop)
    }
  }

  setupDropZone() {
    this.dropZoneElement = this.hasDropzoneTarget ? this.dropzoneTarget : this.element
    
    this.handleDragOver = this.onDragOver.bind(this)
    this.handleDragLeave = this.onDragLeave.bind(this)
    this.handleDrop = this.onDrop.bind(this)
    
    this.dropZoneElement.addEventListener("dragover", this.handleDragOver)
    this.dropZoneElement.addEventListener("dragleave", this.handleDragLeave)
    this.dropZoneElement.addEventListener("drop", this.handleDrop)
  }

  /**
   * Handle file selection from input
   */
  preview(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.processFiles(files)
    }
  }

  /**
   * Handle drag over
   */
  onDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneElement.classList.add("border-amber-500", "bg-amber-50", "dark:bg-amber-900/10")
  }

  /**
   * Handle drag leave
   */
  onDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneElement.classList.remove("border-amber-500", "bg-amber-50", "dark:bg-amber-900/10")
  }

  /**
   * Handle file drop
   */
  onDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneElement.classList.remove("border-amber-500", "bg-amber-50", "dark:bg-amber-900/10")
    
    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.processFiles(files)
    }
  }

  /**
   * Process selected files
   */
  processFiles(files) {
    const file = files[0] // Handle single file for now
    
    // Validate file type
    if (!this.validateType(file)) {
      this.showError(`Invalid file type. Allowed: ${this.acceptValue || "all files"}`)
      return
    }
    
    // Validate file size
    if (!this.validateSize(file)) {
      this.showError(`File too large. Maximum size: ${this.formatFileSize(this.maxSizeValue)}`)
      return
    }
    
    // Set file on input if dropped
    if (this.hasInputTarget && !this.inputTarget.files.length) {
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(file)
      this.inputTarget.files = dataTransfer.files
    }
    
    // Show preview
    this.showFileInfo(file)
    
    if (this.previewValue && this.isImage(file)) {
      this.showImagePreview(file)
    }
    
    // Show remove button
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.classList.remove("hidden")
    }
    
    // Dispatch event
    this.dispatch("select", { detail: { file } })
  }

  /**
   * Validate file type against accept attribute
   */
  validateType(file) {
    if (!this.acceptValue) return true
    
    const acceptTypes = this.acceptValue.split(",").map(t => t.trim())
    
    return acceptTypes.some(type => {
      if (type === "*/*") return true
      if (type.endsWith("/*")) {
        const category = type.replace("/*", "")
        return file.type.startsWith(category)
      }
      if (type.startsWith(".")) {
        return file.name.toLowerCase().endsWith(type.toLowerCase())
      }
      return file.type === type
    })
  }

  /**
   * Validate file size
   */
  validateSize(file) {
    return file.size <= this.maxSizeValue
  }

  /**
   * Check if file is an image
   */
  isImage(file) {
    return file.type.startsWith("image/")
  }

  /**
   * Show file information
   */
  showFileInfo(file) {
    if (!this.hasFilenameTarget) return
    
    const fileName = file.name
    const fileSize = this.formatFileSize(file.size)
    
    this.filenameTarget.innerHTML = `
      <div class="flex items-center gap-2">
        <svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        <span class="font-medium text-slate-900 dark:text-white">${fileName}</span>
        <span class="text-slate-500 dark:text-slate-400">(${fileSize})</span>
      </div>
    `
  }

  /**
   * Show image preview
   */
  showImagePreview(file) {
    if (!this.hasImagePreviewTarget) return
    
    const reader = new FileReader()
    reader.onload = (e) => {
      this.imagePreviewTarget.src = e.target.result
      this.imagePreviewTarget.classList.remove("hidden")
    }
    reader.readAsDataURL(file)
  }

  /**
   * Show existing file preview
   */
  showExistingPreview() {
    if (this.hasImagePreviewTarget && this.existingUrlValue) {
      this.imagePreviewTarget.src = this.existingUrlValue
      this.imagePreviewTarget.classList.remove("hidden")
    }
    
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.classList.remove("hidden")
    }
  }

  /**
   * Show error message
   */
  showError(message) {
    if (!this.hasFilenameTarget) return
    
    this.filenameTarget.innerHTML = `
      <div class="flex items-center gap-2 text-red-600 dark:text-red-400">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <span>${message}</span>
      </div>
    `
    
    // Clear input
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
  }

  /**
   * Show upload progress
   */
  showProgress(percent) {
    if (!this.hasProgressTarget) return
    
    this.progressTarget.classList.remove("hidden")
    this.progressTarget.innerHTML = `
      <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-2">
        <div class="bg-amber-500 h-2 rounded-full transition-all duration-300" style="width: ${percent}%"></div>
      </div>
      <span class="text-xs text-slate-500 dark:text-slate-400">${percent}%</span>
    `
  }

  /**
   * Hide progress bar
   */
  hideProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add("hidden")
    }
  }

  /**
   * Remove selected file
   */
  remove() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
    
    if (this.hasFilenameTarget) {
      this.filenameTarget.innerHTML = `
        <span class="text-slate-500 dark:text-slate-400">No file selected</span>
      `
    }
    
    if (this.hasImagePreviewTarget) {
      this.imagePreviewTarget.src = ""
      this.imagePreviewTarget.classList.add("hidden")
    }
    
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.classList.add("hidden")
    }
    
    this.dispatch("remove")
  }

  /**
   * Format file size for display
   */
  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }
}
