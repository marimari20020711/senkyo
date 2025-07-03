class AddDietDatesAndCommitteesToBills < ActiveRecord::Migration[7.2]
  def change
    add_column :bills, :pre_received_date, :date
    add_column :bills, :pre_refer_date, :date
    add_column :bills, :pre_refer_committee, :string
    add_column :bills, :received_date, :date
    add_column :bills, :refer_date, :date
    add_column :bills, :refer_committee, :string
  end
end
