set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
# データだけ消して再投入
# DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails db:truncate_all
# DBをゼロから作り直す（スキーマ作成 + seed実行）
bundle exec rails db:setup

bundle exec rails db:migrate
bundle exec rails import:sangiin_members
bundle exec rails import:shugiin_members
bundle exec rails scrape:shugiin_hp_bills
bundle exec rails scrape:sangiin_hp_bills
