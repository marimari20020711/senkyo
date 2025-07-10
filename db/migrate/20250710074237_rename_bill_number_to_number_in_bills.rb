class RenameBillNumberToNumberInBills < ActiveRecord::Migration[7.2]
  def change
    rename_column :bills, :bill_number, :number 
  end
end
