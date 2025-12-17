// Tag picker for admin blog posts (search + select + create).
//
// Example usage:
// <div data-controller="tag-picker" data-tag-picker-suggest-url-value="/admin/blog_tags">
//   <input data-tag-picker-target="hidden" type="hidden" name="blog_post[tag_list]" value="tag1,tag2">
//   <div data-tag-picker-target="chips"></div>
//   <input data-tag-picker-target="input" type="text">
//   <div data-tag-picker-target="menu"></div>
// </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "chips", "input", "menu"]
  static values = {
    suggestUrl: String,
  }

  connect() {
    this.tags = this.parseTags(this.hiddenTarget.value)
    this.render()
    this.onDocumentClick = this.onDocumentClick.bind(this)
    document.addEventListener("click", this.onDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
  }

  // data-action="keydown->tag-picker#onKeydown input->tag-picker#onInput"
  onKeydown(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this.addFromInput()
      return
    }

    if (event.key === "Escape") {
      this.closeMenu()
    }
  }

  onInput() {
    const q = this.inputTarget.value.trim()
    if (q.length < 1) {
      this.closeMenu()
      return
    }

    this.fetchSuggestions(q)
  }

  removeTag(event) {
    const tag = event.params.tag
    this.tags = this.tags.filter((t) => t !== tag)
    this.sync()
    this.render()
  }

  pickSuggestion(event) {
    const tag = event.params.tag
    this.addTag(tag)
    this.inputTarget.value = ""
    this.closeMenu()
  }

  addFromInput() {
    const raw = this.inputTarget.value
    this.inputTarget.value = ""
    raw
      .split(",")
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
      .forEach((t) => this.addTag(t))
    this.closeMenu()
  }

  addTag(tag) {
    const cleaned = tag.trim().replace(/^#/, "")
    if (!cleaned) return
    if (this.tags.includes(cleaned)) return
    this.tags.push(cleaned)
    this.tags.sort((a, b) => a.localeCompare(b))
    this.sync()
    this.render()
  }

  sync() {
    this.hiddenTarget.value = this.tags.join(", ")
  }

  render() {
    this.chipsTarget.innerHTML = ""
    this.tags.forEach((tag) => {
      const chip = document.createElement("span")
      chip.className =
        "inline-flex items-center gap-2 px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200"
      chip.textContent = tag

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "text-slate-500 hover:text-slate-700 dark:text-slate-300 dark:hover:text-white"
      btn.innerHTML = "×"
      btn.setAttribute("data-action", "click->tag-picker#removeTag")
      btn.setAttribute("data-tag-picker-tag-param", tag)

      chip.appendChild(btn)
      this.chipsTarget.appendChild(chip)
    })
  }

  async fetchSuggestions(q) {
    if (!this.hasSuggestUrlValue) return

    const url = new URL(this.suggestUrlValue, window.location.origin)
    url.searchParams.set("q", q)

    const res = await fetch(url.toString(), { headers: { Accept: "application/json" } })
    if (!res.ok) return

    const data = await res.json()
    const tags = (data.tags || []).filter((t) => !this.tags.includes(t))
    this.renderMenu(tags)
  }

  renderMenu(tags) {
    this.menuTarget.innerHTML = ""
    if (!tags.length) return

    this.menuTarget.className =
      "mt-2 border border-slate-200 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 shadow-sm overflow-hidden"

    tags.forEach((tag) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className =
        "w-full text-left px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
      item.textContent = tag
      item.setAttribute("data-action", "click->tag-picker#pickSuggestion")
      item.setAttribute("data-tag-picker-tag-param", tag)
      this.menuTarget.appendChild(item)
    })
  }

  closeMenu() {
    this.menuTarget.innerHTML = ""
    this.menuTarget.className = ""
  }

  onDocumentClick(event) {
    if (!this.element.contains(event.target)) this.closeMenu()
  }

  parseTags(value) {
    return value
      .split(",")
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
  }
}


