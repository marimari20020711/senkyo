class AddDetailsToPoliticians < ActiveRecord::Migration[7.2]
  def change
    add_column :politicians, :name_reading, :string
    add_column :politicians, :real_name, :string
    add_column :politicians, :name_of_house, :string
    add_column :politicians, :district, :string
    add_column :politicians, :winning_year, :string
    add_column :politicians, :birth, :date
    add_column :politicians, :position, :text
    add_column :politicians, :winning_count, :string
    add_column :politicians, :profile, :text
  end
end
