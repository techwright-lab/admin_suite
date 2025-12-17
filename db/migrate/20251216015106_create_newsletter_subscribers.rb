class CreateNewsletterSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletter_subscribers do |t|
      t.string :email, null: false

      t.timestamps
    end

    add_index :newsletter_subscribers, :email, unique: true
  end
end
