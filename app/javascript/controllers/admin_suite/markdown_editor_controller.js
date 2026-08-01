import { Controller } from "@hotwired/stimulus"

/**
 * Markdown Editor Controller (Admin Suite)
 *
 * Initializes EasyMDE on a textarea element for rich markdown editing.
 * EasyMDE is loaded from the engine's vendored asset (see app/assets/vendor)
 * only on pages that render a markdown field.
 */

// Bounded retry: ~50 attempts at 100ms each (~5s) before giving up. Guards
// against an unbounded poll if the EasyMDE asset fails to load (e.g. blocked
// by a CSP, 404, or a page that never actually included it).
const MAX_INIT_ATTEMPTS = 50
const INIT_RETRY_DELAY_MS = 100

export default class extends Controller {
  static targets = ["textarea"]

  connect() {
    this.initAttempts = 0
    this.initEditor()
  }

  initEditor() {
    if (typeof window.EasyMDE === "undefined") {
      this.initAttempts += 1
      if (this.initAttempts >= MAX_INIT_ATTEMPTS) {
        console.warn(
          "admin-suite--markdown-editor: EasyMDE failed to load after " +
            MAX_INIT_ATTEMPTS +
            " attempts; falling back to a plain textarea."
        )
        return
      }

      setTimeout(() => this.initEditor(), INIT_RETRY_DELAY_MS)
      return
    }

    if (this.editor) return

    this.editor = new window.EasyMDE({
      element: this.textareaTarget,
      spellChecker: false,
      autofocus: false,
      autosave: { enabled: false },
      status: ["lines", "words", "cursor"],
      placeholder: "Write your content in Markdown...",
      toolbar: [
        "bold",
        "italic",
        "heading",
        "|",
        "quote",
        "unordered-list",
        "ordered-list",
        "|",
        "link",
        "image",
        "code",
        "|",
        "preview",
        "side-by-side",
        "fullscreen",
        "|",
        "guide",
      ],
      minHeight: "400px",
      renderingConfig: { codeSyntaxHighlighting: true },
      forceSync: true,
    })

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

