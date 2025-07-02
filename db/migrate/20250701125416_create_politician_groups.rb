class CreatePoliticianGroups < ActiveRecord::Migration[7.2]
  def change
    create_table :politician_groups do |t|
      t.references :politician, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true

      t.timestamps
    end
  end
end
