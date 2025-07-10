class CreateSpeeches < ActiveRecord::Migration[7.2]
  def change
    create_table :speeches do |t|
      t.references :politician, null: false, foreign_key: true
      t.date :meeting_date
      t.string :source_url
      t.text :body
      t.string :session
      t.integer :speech_order
      t.string :name_of_meeting
      t.string :name_of_house
      t.string :external_speech_id
      t.text :ai_summary

      t.timestamps
    end
  end
end
