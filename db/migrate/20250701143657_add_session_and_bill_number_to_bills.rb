class AddSessionAndBillNumberToBills < ActiveRecord::Migration[7.2]
  def change
    add_column :bills, :session, :string
    add_column :bills, :bill_number, :string
  end
end
