require 'bundler/setup'
Bundler.require

STDOUT.sync = true

DB = Sequel.connect(ENV['DATABASE_URL'] || "postgres://localhost/clorox",
  :max_connections => ENV['MAX_DB_CONNECTIONS'] ? ENV['MAX_DB_CONNECTIONS'].to_i : 4
)
DB.extension :pg_hstore

LOG_PARSER = Parsley.parser(ENV['SYSLOG_FLAVOR'] || :heroku).new