set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

# データだけ消して再投入
#Dashboard → Environment → Environment Variables で、Key: RESET_DB、Value: true を設定すると、DBリセットモードで動作します
if [ "$RESET_DB" = "true" ]; then
  echo "⚠️ RESET_DB=true が設定されているので DB をリセットします"
  DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails db:drop db:create db:migrate
else
  echo "➡️ 通常モード: 既存DBを保持して migrate のみ実行"
  bundle exec rails db:migrate
fi

bundle exec rails db:migrate
bundle exec rails import:sangiin_members
bundle exec rails import:shugiin_members
bundle exec rails scrape:shugiin_hp_bills
bundle exec rails scrape:sangiin_hp_bills
