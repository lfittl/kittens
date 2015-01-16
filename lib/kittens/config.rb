require 'bundler/setup'
Bundler.require

STDOUT.sync = true

DB = Sequel.connect(ENV['DATABASE_URL'], max_connections: Integer(ENV['MAX_DB_CONNECTIONS'] || 4))
