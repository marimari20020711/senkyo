class AddSangiHpColumnsToBills < ActiveRecord::Migration[7.2]
  def change
    add_column :bills, :sangi_hp_body_link, :string
    add_column :bills, :sangi_hp_body_text, :text
  end
end
