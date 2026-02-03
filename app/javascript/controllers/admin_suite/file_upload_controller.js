import { Controller } from "@hotwired/stimulus"

/**
 * File Upload Controller (Admin Suite)
 */
export default class extends Controller {
  static targets = ["input", "filename", "dropzone", "imagePreview", "progress", "removeButton"]

  static values = {
    accept: { type: String, default: "" },
    maxSize: { type: Number, default: 10485760 },
    preview: { type: Boolean, default: false },
    multiple: { type: Boolean, default: false },
    existingUrl: String,
  }

  connect() {
    this.setupDropZone()

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

  preview(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.processFiles(files)
    }
  }

  onDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneElement.classList.add("border-amber-500", "bg-amber-50", "dark:bg-amber-900/10")
  }

  onDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneElement.classList.remove("border-amber-500", "bg-amber-50", "dark:bg-amber-900/10")
  }

  onDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneElement.classList.remove("border-amber-500", "bg-amber-50", "dark:bg-amber-900/10")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.processFiles(files)
    }
  }

  processFiles(files) {
    const file = files[0]

    if (!this.validateType(file)) {
      this.showError(`Invalid file type. Allowed: ${this.acceptValue || "all files"}`)
      return
    }

    if (!this.validateSize(file)) {
      this.showError(`File too large. Maximum size: ${this.formatFileSize(this.maxSizeValue)}`)
      return
    }

    if (this.hasInputTarget && !this.inputTarget.files.length) {
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(file)
      this.inputTarget.files = dataTransfer.files
    }

    this.showFileInfo(file)

    if (this.previewValue && this.isImage(file)) {
      this.showImagePreview(file)
    }

    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.classList.remove("hidden")
    }

    this.dispatch("select", { detail: { file } })
  }

  validateType(file) {
    if (!this.acceptValue) return true

    const acceptTypes = this.acceptValue.split(",").map((t) => t.trim())

    return acceptTypes.some((type) => {
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

  validateSize(file) {
    return file.size <= this.maxSizeValue
  }

  isImage(file) {
    return file.type.startsWith("image/")
  }

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

  showImagePreview(file) {
    if (!this.hasImagePreviewTarget) return

    const reader = new FileReader()
    reader.onload = (e) => {
      this.imagePreviewTarget.src = e.target.result
      this.imagePreviewTarget.classList.remove("hidden")
    }
    reader.readAsDataURL(file)
  }

  showExistingPreview() {
    if (this.hasImagePreviewTarget && this.existingUrlValue) {
      this.imagePreviewTarget.src = this.existingUrlValue
      this.imagePreviewTarget.classList.remove("hidden")
    }

    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.classList.remove("hidden")
    }
  }

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

    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
  }

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

  hideProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add("hidden")
    }
  }

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

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }
}

