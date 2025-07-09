class AddColumnToPoliticians < ActiveRecord::Migration[7.2]
  def change
    add_column :politicians, :term_end, :date
  end
end
