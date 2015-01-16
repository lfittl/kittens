web: bundle exec ruby -I./lib -r kittens ./lib/kittens/server.rb -sv -e $RACK_ENV -p $PORT
migrate: sequel -m ./db/migrations $DATABASE_URL
