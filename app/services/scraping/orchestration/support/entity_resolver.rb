# frozen_string_literal: true

module Scraping
  module Orchestration
    module Support
      module EntityResolver
        module_function

        def find_or_create_company(context, name)
          job_listing = context.job_listing
          return job_listing.company if name.blank?

          normalized_name = normalize_company_name(name)
          domain = extract_domain_from_url(job_listing.url)

          if job_listing.company.present?
            existing_company = job_listing.company

            if domain.present? && existing_company.website.present?
              existing_domain = extract_domain_from_url(existing_company.website)
              return existing_company if domains_match?(domain, existing_domain)
            end

            existing_normalized = normalize_company_name(existing_company.name)
            return existing_company if names_similar?(normalized_name, existing_normalized)
          end

          if domain.present?
            company = find_company_by_domain(domain)
            return company if company
          end

          company = Company.find_by(name: normalized_name)
          return company if company

          company = find_similar_company(normalized_name)
          return company if company

          Company.create!(name: normalized_name) do |c|
            c.website = "https://#{domain}" if domain.present?
          end
        end

        def find_or_create_job_role(context, title, department_name: nil)
          job_listing = context.job_listing
          return job_listing.job_role if title.blank?

          normalized_title = normalize_job_role_title(title)
          job_role = JobRole.find_or_create_by(title: normalized_title)

          # Assign department if provided and role doesn't have one
          if department_name.present? && job_role.category_id.nil?
            department = Category.find_by(name: department_name, kind: :job_role)
            department ||= infer_department_from_title(normalized_title)
            job_role.update(category: department) if department
          elsif job_role.category_id.nil?
            # Try to infer department from title if not provided
            department = infer_department_from_title(normalized_title)
            job_role.update(category: department) if department
          end

          job_role
        end

        def infer_department_from_title(title)
          return nil if title.blank?

          title_lower = title.downcase

          department_keywords = {
            "Engineering" => %w[engineer developer software backend frontend fullstack architect sre devops platform],
            "Product" => %w[product owner manager pm],
            "Design" => %w[designer ux ui visual graphic],
            "Data Science" => %w[data scientist analyst analytics machine learning ml ai],
            "DevOps/SRE" => %w[devops sre infrastructure reliability platform],
            "Sales" => %w[sales account executive ae sdr bdr],
            "Marketing" => %w[marketing growth seo sem content brand],
            "Customer Success" => %w[customer success support cx],
            "Finance" => %w[finance accounting financial controller cfo],
            "HR/People" => %w[hr human resources people talent recruiter recruiting],
            "Legal" => %w[legal counsel attorney compliance],
            "Operations" => %w[operations ops logistics supply],
            "Executive" => %w[ceo cto coo cfo cmo chief director vp president],
            "Research" => %w[research scientist r&d],
            "QA/Testing" => %w[qa quality assurance test tester sdet],
            "Security" => %w[security infosec appsec cyber],
            "IT" => %w[it helpdesk administrator admin sysadmin],
            "Content" => %w[content writer editor copywriter]
          }

          department_keywords.each do |dept_name, keywords|
            if keywords.any? { |kw| title_lower.include?(kw) }
              return Category.find_by(name: dept_name, kind: :job_role)
            end
          end

          nil
        end

        def normalize_company_name(name)
          return nil if name.blank?

          normalized = name.strip
          suffixes = [
            /\s+inc\.?$/i,
            /\s+llc\.?$/i,
            /\s+corp\.?$/i,
            /\s+corporation$/i,
            /\s+ltd\.?$/i,
            /\s+limited$/i,
            /\s+co\.?$/i,
            /\s+company$/i,
            /\s+\.io$/i,
            /\s+\.com$/i,
            /\s+\.net$/i,
            /\s+\.org$/i
          ]
          suffixes.each { |suffix| normalized = normalized.gsub(suffix, "") }

          normalized.strip.titleize
        end

        def normalize_job_role_title(title)
          return nil if title.blank?
          title.strip
        end

        def names_similar?(name1, name2)
          return false if name1.blank? || name2.blank?
          return true if name1.downcase == name2.downcase

          n1 = name1.downcase
          n2 = name2.downcase
          return true if n1.include?(n2) || n2.include?(n1)

          # Also compare without spaces (handles "Ever Ai" vs "EverAI")
          n1_compact = n1.gsub(/\s+/, "")
          n2_compact = n2.gsub(/\s+/, "")
          return true if n1_compact == n2_compact
          return true if n1_compact.include?(n2_compact) || n2_compact.include?(n1_compact)

          distance = levenshtein_distance(n1, n2)
          max_distance = [ name1.length, name2.length ].min / 3
          distance <= [ max_distance, 2 ].max
        end

        def levenshtein_distance(str1, str2)
          m, n = str1.length, str2.length
          return n if m == 0
          return m if n == 0

          d = Array.new(m + 1) { Array.new(n + 1) }
          (0..m).each { |i| d[i][0] = i }
          (0..n).each { |j| d[0][j] = j }

          (1..n).each do |j|
            (1..m).each do |i|
              d[i][j] = if str1[i - 1] == str2[j - 1]
                d[i - 1][j - 1]
              else
                [ d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + 1 ].min
              end
            end
          end

          d[m][n]
        end

        def extract_domain_from_url(url)
          return nil if url.blank?

          uri = URI.parse(url)
          domain = uri.host
          return nil unless domain

          domain = domain.downcase
          domain.sub(/^www\./, "")
        rescue
          nil
        end

        def normalize_domain(domain)
          return "" if domain.blank?
          domain = domain.gsub(/^https?:\/\//, "")
          domain = domain.split("/").first
          domain = domain.downcase
          domain.sub(/^www\./, "")
        end

        def domains_match?(domain1, domain2)
          return false if domain1.blank? || domain2.blank?

          norm1 = normalize_domain(domain1)
          norm2 = normalize_domain(domain2)
          return true if norm1 == norm2

          return true if norm1.end_with?(".#{norm2}") || norm2.end_with?(".#{norm1}")

          parts1 = norm1.split(".")
          parts2 = norm2.split(".")
          if parts1.length >= 2 && parts2.length >= 2
            base1 = parts1[-2..-1].join(".")
            base2 = parts2[-2..-1].join(".")
            return true if base1 == base2
          end

          false
        end

        def find_company_by_domain(domain)
          return nil if domain.blank?
          normalized = normalize_domain(domain)

          Company.where.not(website: nil).find_each do |company|
            company_domain = extract_domain_from_url(company.website)
            return company if company_domain.present? && domains_match?(normalized, company_domain)
          end

          nil
        end

        def find_similar_company(normalized_name)
          return nil if normalized_name.blank?

          Company.find_each do |company|
            existing_normalized = normalize_company_name(company.name)
            return company if names_similar?(normalized_name, existing_normalized)
          end

          nil
        end
      end
    end
  end
end
