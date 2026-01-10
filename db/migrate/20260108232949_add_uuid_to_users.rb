class AddUuidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :uuid, :string
    add_index :users, :uuid, unique: true

    add_column :users, :slug, :string
    add_index :users, :slug, unique: true

    backfill_uuid_slugs
  end

  private

  # Backfills the UUID for existing users
  # @return [void]
  def backfill_uuid_slugs
    ids = select_values("SELECT id FROM users WHERE uuid IS NULL")
    ids.each do |id|
      execute <<~SQL.squish
        UPDATE users
        SET uuid = '#{SecureRandom.uuid}'
        WHERE id = #{id.to_i} AND uuid IS NULL
      SQL
    end

    User.find_each(&:save)
  end
end
