class AddColumnsToBills < ActiveRecord::Migration[7.2]
  def change
    add_column :bills, :ai_summary, :text
    add_column :bills, :body_link, :string
    add_column :bills, :body_text, :text
  end
end
