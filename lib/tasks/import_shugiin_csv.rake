# lib/tasks/import_sangiin_csv.rake

namespace :import do
  desc "Import Shugiin politicians from CSV"
  task shugiin_members: :environment do
    require 'csv'

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
                         when /国民/ then "国国民民主党・無所属クラブ"
                         when /自民/ then "自由民主党・無所属の会"
                         when /公明/ then "公明党"
                         when /共産/ then "日本共産党"
                         when /維新/ then "日本維新の会"
                         when /れ新/ then "れいわ新選組"
                         when /沖縄/ then "沖縄の風"
                         when /N党|Ｎ/ then "ＮＨＫから国民を守る党"
                         when /無所属/ then "各派に属しない議員"
                         when /参政/ then "参政党"
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

      group = Group.find_or_create_by!(name: simplified_group)
      PoliticianGroup.find_or_create_by!(politician: politician, group: group)

      puts "登録: #{name_only}（#{simplified_group}） 選挙区: #{district} 当選回数: #{winning_count}"
    end
    puts "インポート完了"
  end
end
