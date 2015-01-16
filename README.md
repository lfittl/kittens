# kittens

Log drain target for your Heroku router logs to help you find 404s, 500s and timeouts errors.

![kittens example screenshot](https://dl.dropboxusercontent.com/u/6237890/product_screenshots/kittens.png)

Heavily modified fork of [heroku-log-store](https://github.com/rwdaigle/heroku-log-store), storing log data in an attached PostgreSQL database.

## Deploy

kittens is deployed best on Heroku, and set up as a log drain for your main application.

```term
$ git clone git://github.com/lfittl/kittens.git
$ cd kittens
$ heroku create my-app-kittens
$ heroku config:set RACK_ENV=production
$ heroku config:set HTTP_AUTH_USER=myuser
$ heroku config:set HTTP_AUTH_PASSWORD=mypassword
$ heroku addons:add heroku-postgresql:basic
$ git push heroku master
```

Note that its probably a bad idea to run this on the free Heroku Postgres tier,
because of the 10,000 row limit.

## Setup database

Create the initial database structure using

```term
$ heroku run migrate
Running `migrate` attached to terminal... up, run.4179
```

## Setup Logdrain

Now, add the log drain to your main application:

```
$ heroku drains:add https://myuser:mypassword@my-app-kittens.herokuapp.com/drain --app my-app
```

To verify that you are receiving data correctly, view the kittens logs using ```heroku logs --tail```.

Now, if you go to the main page of the app, it should show first data (check the 404 list, that one is easy to test).

## Slack Notifications

![slack screenshot](https://dl.dropboxusercontent.com/u/6237890/product_screenshots/kittens_slack.png)

To setup daily notifications to Slack, use the Heroku scheduler add-on,
and have it call ```rake daily_report``` every 24 hours.

In addition set the ```SLACK_WEBHOOK``` and ```APP_URL``` env variables appropriately.

## Authors

* [Lukas Fittl](https://twitter.com/LukasFittl)
* [@rwdaigle](https://twitter.com/rwdaigle) (author of original [heroku-log-store](https://github.com/rwdaigle/heroku-log-store))
