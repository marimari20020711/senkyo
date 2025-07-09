class ChangeTermEndTypeInPoliticians < ActiveRecord::Migration[7.2]
  def change
    change_column :politicians, :term_end, :string
  end
end
