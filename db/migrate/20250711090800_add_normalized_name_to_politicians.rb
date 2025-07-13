class AddNormalizedNameToPoliticians < ActiveRecord::Migration[7.2]
  def change
    add_column :politicians, :normalized_name, :string
  end
end
