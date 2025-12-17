# frozen_string_literal: true

class MigrateIgnoredOpportunitiesToArchived < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE opportunities
      SET status = 'archived',
          archived_reason = 'ignored',
          archived_at = COALESCE(archived_at, updated_at)
      WHERE status = 'ignored'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE opportunities
      SET status = 'ignored',
          archived_reason = NULL,
          archived_at = NULL
      WHERE status = 'archived' AND archived_reason = 'ignored'
    SQL
  end
end



