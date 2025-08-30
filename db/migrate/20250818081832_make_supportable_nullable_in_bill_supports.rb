class MakeSupportableNullableInBillSupports < ActiveRecord::Migration[7.2]
  def change
    change_column_null :bill_supports, :supportable_type, true
    change_column_null :bill_supports, :supportable_id, true
  end
end
