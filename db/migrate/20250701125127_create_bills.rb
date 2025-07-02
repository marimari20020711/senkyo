class CreateBills < ActiveRecord::Migration[7.2]
  def change
    create_table :bills do |t|
      t.string :title
      t.string :kind
      t.string :discussion_status
      t.text :summary_text
      t.string :summary_link

      t.timestamps
    end
  end
end
