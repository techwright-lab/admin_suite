# frozen_string_literal: true

# Pagy Configuration
# See https://ddnexus.github.io/pagy/docs/how-to/
#

require "pagy/extras/overflow"
require "pagy/extras/metadata"
require "pagy/extras/array"

# Default items per page
Pagy::DEFAULT[:limit] = 20

# Handle overflow by returning the last page
Pagy::DEFAULT[:overflow] = :last_page

# Maximum items per page (for safety)
Pagy::DEFAULT[:max_limit] = 100

