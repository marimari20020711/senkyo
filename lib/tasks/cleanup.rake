namespace :cleanup do
  desc "全てのデータを安全に削除"
  task reset_all_data: :environment do
    if Rails.env.production?
      puts "❌ 本番環境では実行できません"
      exit 1
    end
    
    print "本当に全てのデータを削除しますか？ (yes/no): "
    response = STDIN.gets.chomp
    
    unless response.downcase == 'yes'
      puts "❌ キャンセルしました"
      exit 0
    end
    
    puts "🗑️ 全データを削除中..."
    
    begin
      # 削除前の件数確認
      counts = {
        bill_supports: BillSupport.count,
        politician_groups: PoliticianGroup.count,
        speeches: Speech.count,
        bills: Bill.count,
        politicians: Politician.count,
        groups: Group.count
      }
      
      puts "削除前のデータ数:"
      counts.each { |table, count| puts "  #{table}: #{count}件" }
      
      # 外部キーを持つテーブルから削除
      BillSupport.delete_all
      puts "✅ BillSupport削除完了"
      
      PoliticianGroup.delete_all
      puts "✅ PoliticianGroup削除完了"
      
      Speech.delete_all
      puts "✅ Speech削除完了"
      
      # 参照されるテーブルを削除
      Bill.delete_all
      puts "✅ Bill削除完了"
      
      Politician.delete_all
      puts "✅ Politician削除完了"
      
      Group.delete_all
      puts "✅ Group削除完了"
      
      # IDリセット
      tables = %w[bill_supports politician_groups speeches bills politicians groups]
      tables.each do |table|
        ActiveRecord::Base.connection.reset_pk_sequence!(table)
      end
      puts "🔄 IDシーケンスリセット完了"
      
      # 削除後の確認
      puts "\n📊 削除後のデータ数:"
      puts "  BillSupport: #{BillSupport.count}件"
      puts "  PoliticianGroup: #{PoliticianGroup.count}件"
      puts "  Speech: #{Speech.count}件"
      puts "  Bill: #{Bill.count}件"
      puts "  Politician: #{Politician.count}件"
      puts "  Group: #{Group.count}件"
      
      total_deleted = counts.values.sum
      puts "\n🎉 合計 #{total_deleted}件のデータを削除しました"
      
    rescue => e
      puts "❌ エラーが発生しました: #{e.message}"
      puts "🔍 詳細: #{e.backtrace.first(3).join('\n')}"
    end
  end
  
  desc "IDリセットなしでデータのみ削除"
  task clear_all_data: :environment do
    puts "🗑️ 全データを削除中（IDリセットなし）..."
    
    begin
      # 削除順序を守って実行
      BillSupport.delete_all
      PoliticianGroup.delete_all
      Speech.delete_all
      Bill.delete_all
      Politician.delete_all
      Group.delete_all
      
      puts "✅ 全データ削除完了"
      
    rescue => e
      puts "❌ エラー: #{e.message}"
    end
  end
  
  desc "特定のテーブルのみ削除"
  task :clear_table, [:table_name] => :environment do |task, args|
    table_name = args[:table_name]
    
    unless table_name
      puts "❌ テーブル名を指定してください"
      puts "例: bin/rails cleanup:clear_table[bills]"
      exit 1
    end
    
    begin
      model_class = table_name.classify.constantize
      count = model_class.count
      model_class.delete_all
      
      puts "✅ #{table_name}テーブル: #{count}件削除完了"
      
    rescue NameError
      puts "❌ #{table_name}に対応するモデルが見つかりません"
    rescue => e
      puts "❌ エラー: #{e.message}"
    end
  end
end
