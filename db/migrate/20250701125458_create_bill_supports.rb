class CreateBillSupports < ActiveRecord::Migration[7.2]
  def change
    create_table :bill_supports do |t|
      t.references :bill, null: false, foreign_key: true
      t.references :supportable, polymorphic: true, null: false
      t.string :support_type

      t.timestamps
    end
  end
end
