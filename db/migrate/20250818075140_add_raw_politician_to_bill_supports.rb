class AddRawPoliticianToBillSupports < ActiveRecord::Migration[7.2]
  def change
    add_column :bill_supports, :raw_politician, :string
  end
end
