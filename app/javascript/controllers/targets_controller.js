import { Controller } from "@hotwired/stimulus"

/**
 * Targets Controller
 * Handles search-as-you-type for roles, companies, and domains
 */
export default class extends Controller {
  static targets = [
    "roleSearch", "roleResults", "departmentFilter", "selectedRoles",
    "companySearch", "companyResults", "selectedCompanies",
    "domainSearch", "domainResults", "selectedDomains"
  ]

  static values = {
    debounceMs: { type: Number, default: 300 }
  }

  connect() {
    this.debounceTimers = {}
  }

  disconnect() {
    // Clear any pending timers
    Object.values(this.debounceTimers).forEach(timer => clearTimeout(timer))
  }

  /**
   * Debounced search for job roles
   */
  searchRoles(event) {
    this.debounce("roles", () => this.performRoleSearch(event.target.value))
  }

  /**
   * Filter roles by department
   */
  filterByDepartment(event) {
    const departmentId = event.target.value
    const query = this.hasRoleSearchTarget ? this.roleSearchTarget.value : ""
    this.performRoleSearch(query, departmentId)
  }

  /**
   * Performs the actual role search API call
   */
  async performRoleSearch(query, departmentId = null) {
    if (!this.hasRoleResultsTarget) return

    if (!query && !departmentId) {
      this.roleResultsTarget.classList.add("hidden")
      return
    }

    try {
      const params = new URLSearchParams()
      if (query) params.append("q", query)
      if (departmentId) params.append("department_id", departmentId)
      params.append("limit", "20")

      const response = await fetch(`/api/v1/job_roles?${params}`)
      const data = await response.json()

      this.renderRoleResults(data.job_roles, query)
    } catch (error) {
      console.error("Role search failed:", error)
    }
  }

  /**
   * Renders role search results
   */
  renderRoleResults(roles, query) {
    if (!this.hasRoleResultsTarget) return

    let html = ""

    if (roles.length === 0) {
      html = `
        <div class="p-3 text-center">
          <p class="text-sm text-gray-500 dark:text-gray-400">No roles found</p>
          ${query ? `
            <button type="button" 
                    class="mt-2 text-sm text-primary-600 hover:text-primary-700 dark:text-primary-400"
                    data-action="click->targets#createRole"
                    data-query="${this.escapeHtml(query)}">
              + Create "${this.escapeHtml(query)}"
            </button>
          ` : ""}
        </div>
      `
    } else {
      html = roles.map(role => `
        <button type="button"
                class="w-full px-4 py-2 text-left hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center justify-between"
                data-action="click->targets#selectRole"
                data-role-id="${role.id}"
                data-role-title="${this.escapeHtml(role.title)}">
          <span class="text-sm text-gray-900 dark:text-white">${this.escapeHtml(role.title)}</span>
          ${role.department_name ? `<span class="text-xs text-gray-500 dark:text-gray-400">${this.escapeHtml(role.department_name)}</span>` : ""}
        </button>
      `).join("")

      // Add create option at the end if there's a query
      if (query) {
        html += `
          <div class="border-t border-gray-100 dark:border-gray-700">
            <button type="button" 
                    class="w-full px-4 py-2 text-left text-sm text-primary-600 hover:bg-gray-50 dark:hover:bg-gray-700 dark:text-primary-400"
                    data-action="click->targets#createRole"
                    data-query="${this.escapeHtml(query)}">
              + Create "${this.escapeHtml(query)}"
            </button>
          </div>
        `
      }
    }

    this.roleResultsTarget.innerHTML = html
    this.roleResultsTarget.classList.remove("hidden")
  }

  /**
   * Selects a role from search results
   */
  async selectRole(event) {
    const roleId = event.currentTarget.dataset.roleId
    
    try {
      const response = await fetch("/settings/targets/add_role", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": this.csrfToken
        },
        body: `job_role_id=${roleId}`
      })

      if (response.ok) {
        // Reload page to show updated targets
        window.location.reload()
      }
    } catch (error) {
      console.error("Failed to add role:", error)
    }
  }

  /**
   * Debounced search for companies
   */
  searchCompanies(event) {
    this.debounce("companies", () => this.performCompanySearch(event.target.value))
  }

  /**
   * Performs the actual company search API call
   */
  async performCompanySearch(query) {
    if (!this.hasCompanyResultsTarget) return

    if (!query || query.length < 2) {
      this.companyResultsTarget.classList.add("hidden")
      return
    }

    try {
      const params = new URLSearchParams({ q: query, limit: "20" })
      const response = await fetch(`/api/v1/companies?${params}`)
      const data = await response.json()

      this.renderCompanyResults(data.companies, query)
    } catch (error) {
      console.error("Company search failed:", error)
    }
  }

  /**
   * Renders company search results
   */
  renderCompanyResults(companies, query) {
    if (!this.hasCompanyResultsTarget) return

    let html = ""

    if (companies.length === 0) {
      html = `
        <div class="p-3 text-center">
          <p class="text-sm text-gray-500 dark:text-gray-400">No companies found</p>
          <button type="button" 
                  class="mt-2 text-sm text-primary-600 hover:text-primary-700 dark:text-primary-400"
                  data-action="click->targets#createCompany"
                  data-query="${this.escapeHtml(query)}">
            + Create "${this.escapeHtml(query)}"
          </button>
        </div>
      `
    } else {
      html = companies.map(company => `
        <button type="button"
                class="w-full px-4 py-2 text-left hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center gap-3"
                data-action="click->targets#selectCompany"
                data-company-id="${company.id}"
                data-company-name="${this.escapeHtml(company.name)}">
          ${company.logo_url ? `<img src="${company.logo_url}" class="w-6 h-6 rounded" alt="">` : ""}
          <span class="text-sm text-gray-900 dark:text-white">${this.escapeHtml(company.name)}</span>
        </button>
      `).join("")

      // Add create option at the end
      html += `
        <div class="border-t border-gray-100 dark:border-gray-700">
          <button type="button" 
                  class="w-full px-4 py-2 text-left text-sm text-primary-600 hover:bg-gray-50 dark:hover:bg-gray-700"
                  data-action="click->targets#createCompany"
                  data-query="${this.escapeHtml(query)}">
            + Create "${this.escapeHtml(query)}"
          </button>
        </div>
      `
    }

    this.companyResultsTarget.innerHTML = html
    this.companyResultsTarget.classList.remove("hidden")
  }

  /**
   * Selects a company from search results
   */
  async selectCompany(event) {
    const companyId = event.currentTarget.dataset.companyId
    
    try {
      const response = await fetch("/settings/targets/add_company", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": this.csrfToken
        },
        body: `company_id=${companyId}`
      })

      if (response.ok) {
        window.location.reload()
      }
    } catch (error) {
      console.error("Failed to add company:", error)
    }
  }

  /**
   * Creates a new company and adds it as target
   */
  async createCompany(event) {
    const name = event.currentTarget.dataset.query
    
    try {
      // First create the company
      const createResponse = await fetch("/api/v1/companies", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ company: { name } })
      })

      const createData = await createResponse.json()
      
      if (createData.success) {
        // Then add it as a target
        await fetch("/settings/targets/add_company", {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "X-CSRF-Token": this.csrfToken
          },
          body: `company_id=${createData.company.id}`
        })
        
        window.location.reload()
      } else {
        alert(createData.errors?.join(", ") || "Failed to create company")
      }
    } catch (error) {
      console.error("Failed to create company:", error)
    }
  }

  /**
   * Creates a new role and adds it as target
   */
  async createRole(event) {
    const title = event.currentTarget.dataset.query
    const departmentId = this.hasDepartmentFilterTarget ? this.departmentFilterTarget.value : null
    
    try {
      const body = { job_role: { title } }
      if (departmentId) body.department_id = departmentId

      const createResponse = await fetch("/api/v1/job_roles", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify(body)
      })

      const createData = await createResponse.json()
      
      if (createData.success) {
        await fetch("/settings/targets/add_role", {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "X-CSRF-Token": this.csrfToken
          },
          body: `job_role_id=${createData.job_role.id}`
        })
        
        window.location.reload()
      } else {
        alert(createData.errors?.join(", ") || "Failed to create role")
      }
    } catch (error) {
      console.error("Failed to create role:", error)
    }
  }

  /**
   * Debounce helper
   */
  debounce(key, fn) {
    if (this.debounceTimers[key]) {
      clearTimeout(this.debounceTimers[key])
    }
    this.debounceTimers[key] = setTimeout(fn, this.debounceMs)
  }

  /**
   * HTML escape helper
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Gets CSRF token
   */
  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  /**
   * Debounce milliseconds
   */
  get debounceMs() {
    return this.debouncesMsValue || 300
  }
}
