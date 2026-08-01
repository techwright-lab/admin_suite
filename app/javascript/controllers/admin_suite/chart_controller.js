import { Controller } from "@hotwired/stimulus"

/**
 * Chart Controller (Admin Suite)
 *
 * Upgrades a server-rendered CSS bar chart into a real Chart.js canvas.
 * Chart.js is loaded from the engine's vendored asset (see app/assets/vendor)
 * only on pages that render a chart panel with data.
 *
 * The server-rendered bar markup (this.element's existing children) is the
 * no-JS degraded state. It stays on the page and visible until Chart.js is
 * confirmed available and a canvas has actually been drawn — if Chart.js
 * never loads, the bars are simply never hidden.
 */

// Bounded retry: ~50 attempts at 100ms each (~5s) before giving up. Guards
// against an unbounded poll if the Chart.js asset fails to load (e.g. blocked
// by a CSP, 404, or a page that never actually included it).
const MAX_INIT_ATTEMPTS = 50
const INIT_RETRY_DELAY_MS = 100

const COLOR_HEX = {
  amber: "#f59e0b",
  green: "#22c55e",
  red: "#ef4444",
  cyan: "#06b6d4",
  violet: "#8b5cf6",
  indigo: "#6366f1",
  slate: "#64748b",
}

const DOUGHNUT_PALETTE = [
  "#6366f1", "#f59e0b", "#22c55e", "#ef4444",
  "#06b6d4", "#8b5cf6", "#64748b", "#ec4899",
]

// Fallback height (px) if the server didn't send a height value for some
// reason. Kept in sync with the ERB partial's own default.
const DEFAULT_HEIGHT_PX = 192

export default class extends Controller {
  static values = {
    series: Array,
    type: String,
    color: String,
    height: Number,
  }

  connect() {
    this.initAttempts = 0
    this.chart = null
    this.canvasWrapper = null
    this.initChart()
  }

  initChart() {
    if (typeof window.Chart === "undefined") {
      this.initAttempts += 1
      if (this.initAttempts >= MAX_INIT_ATTEMPTS) {
        console.warn(
          "admin-suite--chart: Chart.js failed to load after " +
            MAX_INIT_ATTEMPTS +
            " attempts; leaving the server-rendered bar chart in place."
        )
        return
      }

      this.retryTimeout = setTimeout(() => this.initChart(), INIT_RETRY_DELAY_MS)
      return
    }

    // Idempotence guard: never build a second chart on top of an existing one.
    if (this.chart) return

    const series = this.hasSeriesValue ? this.seriesValue : []
    if (series.length === 0) return

    const type = this.hasTypeValue && this.typeValue ? this.typeValue : "bar"
    const color = COLOR_HEX[this.colorValue] || COLOR_HEX.indigo
    const height = this.hasHeightValue && this.heightValue > 0 ? this.heightValue : DEFAULT_HEIGHT_PX

    // Chart.js's `responsive: true` / `maintainAspectRatio: false` combo
    // requires the canvas's parent to have an explicit, non-content-derived
    // height — otherwise there is no reference box to size against, and the
    // canvas can render at 0px or grow unboundedly. The wrapper's height
    // matches the server-rendered bars' height exactly (same data value), so
    // there's no layout shift when the canvas replaces them.
    const wrapper = document.createElement("div")
    wrapper.style.position = "relative"
    wrapper.style.height = `${height}px`
    wrapper.style.width = "100%"

    const canvas = document.createElement("canvas")
    canvas.setAttribute("role", "img")
    canvas.setAttribute("aria-label", "Chart")
    wrapper.appendChild(canvas)

    // Attach to the document before constructing the Chart so Chart.js can
    // actually measure the wrapper's box on first render.
    this.element.appendChild(wrapper)

    const labels = series.map((row) => row.label)
    const values = series.map((row) => row.value)

    const chartType = type === "area" ? "line" : type
    const isDoughnut = chartType === "doughnut"

    const dataset = {
      data: values,
      backgroundColor: isDoughnut ? DOUGHNUT_PALETTE : color,
      borderColor: isDoughnut ? DOUGHNUT_PALETTE : color,
      fill: type === "area",
      tension: 0.3,
    }

    // Only hide the degraded bar markup once Chart.js has actually accepted
    // the config and rendered — this is what keeps the CSS bars visible as
    // the degraded state on any earlier failure path.
    this.chart = new window.Chart(canvas.getContext("2d"), {
      type: chartType,
      data: { labels, datasets: [ dataset ] },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: isDoughnut } },
        scales: isDoughnut ? {} : { y: { beginAtZero: true } },
      },
    })

    this.canvasWrapper = wrapper

    // Hide (not remove) the server-rendered bar markup so it can be restored
    // by simply removing the canvas wrapper if the controller disconnects.
    Array.from(this.element.children).forEach((child) => {
      if (child !== wrapper) child.style.display = "none"
    })
  }

  disconnect() {
    if (this.retryTimeout) {
      clearTimeout(this.retryTimeout)
      this.retryTimeout = null
    }

    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }

    if (this.canvasWrapper) {
      this.canvasWrapper.remove()
      this.canvasWrapper = null
    }

    Array.from(this.element.children).forEach((child) => {
      child.style.display = ""
    })
  }
}
