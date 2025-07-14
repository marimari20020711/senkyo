# lib/tasks/db.rake
namespace :db do
  desc "Truncate all tables (EXCEPT schema_migrations and ar_internal_metadata)"
  task truncate_all: :environment do
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "schema_migrations" || table == "ar_internal_metadata"
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
    end
  end
end
