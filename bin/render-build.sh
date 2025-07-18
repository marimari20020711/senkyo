set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
# 必要に応じてデータ削除
# DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails db:truncate_all
bundle exec rails db:migrate
bundle exec rails import:sangiin_members
bundle exec rails import:shugiin_members
bundle exec rails scrape:shugiin_hp_bills
bundle exec rails scrape:sangiin_hp_bills
