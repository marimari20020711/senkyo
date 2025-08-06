# lib/tasks/import_sangiin_csv.rake

namespace :import do
  desc "Import Shugiin politicians from CSV"
  task shugiin_members: :environment do
    require 'csv'

    puts "🧹 古い衆議院議員データを削除中..."
    shugiin_politicians = Politician.where(name_of_house: "衆議院")
    PoliticianGroup.where(politician_id: shugiin_politicians).delete_all
    shugiin_politicians.delete_all

    groups = Group.all.index_by(&:name)
    path = Rails.root.join("lib/assets/shugiin_members.csv")
    puts "CSV読み込み開始: #{path}"

    CSV.foreach(path, headers: true) do |row|
      name_raw     = row["議員氏名"].to_s.strip
      name_reading = row["読み方"].to_s.strip
      group_name   = row["会派"].to_s.strip
      district     = row["選挙区"].to_s.strip
      winning_count = row["当選回数"].to_s.strip

      # 本名（[小川 のり子] 形式）を抽出
      real_name = name_raw[/\[(.*?)\]/, 1]
      name_only = name_raw.gsub(/\[.*?\]/, "").strip
      normalized_name = name_only.gsub(/[[:space:]]/, "")

      simplified_group = case group_name
                         when /立憲/ then "立憲民主党・無所属"
                         when /国民/ then "国民民主党・無所属クラブ"
                         when /自民/ then "自由民主党・無所属の会"
                         when /公明/ then "公明党"
                         when /共産/ then "日本共産党"
                         when /維新/ then "日本維新の会"
                         when /れ新/ then "れいわ新選組"
                         when /沖縄/ then "沖縄の風"
                         when /N党|Ｎ/ then "ＮＨＫから国民を守る党"
                         when /無/ then "無所属"
                         when /参政/ then "参政党"
                         when /保守/ then "日本保守党"
                         when /有志/ then "有志の会"      

                         else group_name
                         end

      politician = Politician.find_or_initialize_by(normalized_name: normalized_name)
      politician.assign_attributes(
        name: name_only,
        name_reading: name_reading,
        real_name: real_name,
        district: district,
        winning_count: winning_count,
        name_of_house: "衆議院"
      )
      politician.save!

      group = groups[simplified_group] || Group.create!(name: simplified_group)
      .tap { |g| groups[g.name] = g }
      PoliticianGroup.find_or_create_by!(politician: politician, group: group)

      puts "登録: #{name_only}（#{simplified_group}） 選挙区: #{district} 当選回数: #{winning_count}"
    end
    puts "インポート完了"
  end
end
