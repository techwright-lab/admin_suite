import { Controller } from "@hotwired/stimulus"

/**
 * Markdown Editor Controller
 * 
 * Initializes EasyMDE on a textarea element for rich markdown editing.
 * EasyMDE is loaded globally via script tag in the admin layout.
 * 
 * Usage:
 *   <div data-controller="markdown-editor">
 *     <textarea data-markdown-editor-target="textarea"></textarea>
 *   </div>
 */
export default class extends Controller {
  static targets = ["textarea"]

  connect() {
    this.initEditor()
  }

  initEditor() {
    // Wait for EasyMDE to be available (loaded via script tag)
    if (typeof window.EasyMDE === "undefined") {
      // Retry after a short delay if script hasn't loaded yet
      setTimeout(() => this.initEditor(), 100)
      return
    }

    // Don't initialize twice
    if (this.editor) return

    this.editor = new window.EasyMDE({
      element: this.textareaTarget,
      spellChecker: false,
      autofocus: false,
      autosave: {
        enabled: false
      },
      status: ["lines", "words", "cursor"],
      placeholder: "Write your content in Markdown...",
      toolbar: [
        "bold", "italic", "heading", "|",
        "quote", "unordered-list", "ordered-list", "|",
        "link", "image", "code", "|",
        "preview", "side-by-side", "fullscreen", "|",
        "guide"
      ],
      minHeight: "400px",
      renderingConfig: {
        codeSyntaxHighlighting: true
      },
      forceSync: true
    })

    // Sync changes back to the original textarea for form submission
    this.editor.codemirror.on("change", () => {
      this.textareaTarget.value = this.editor.value()
    })
  }

  disconnect() {
    if (this.editor) {
      this.editor.toTextArea()
      this.editor = null
    }
  }
}
