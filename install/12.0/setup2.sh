cat << EOF

================== [kmyblue setup script 2] ======================
Install Ruby

EOF

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
RUBY_CONFIGURE_OPTS=--with-jemalloc rbenv install 3.2.3
rbenv global 3.2.3

cat << EOF

================== [kmyblue setup script 2] ======================
Install Ruby bundler

EOF

gem install bundler --no-document

cd ~/live

cat << EOF

================== [kmyblue setup script 2] ======================
Install yarn packages

EOF

yarn install

cat << EOF

================== [kmyblue setup script 2] ======================
Install bundle packages

EOF

bundle config deployment 'true'
bundle config without 'development test'
bundle install -j$(getconf _NPROCESSORS_ONLN)

# ---------------------------------------------------

cat << EOF

============== [kmyblue setup script 2 completed] ================

PostgreSQL and Redis are now available on localhost.

* PostgreSQL
    host     : /var/run/postgresql
    user     : mastodon
    database : mastodon_production
    password : ohagi

* Redis
    host     : localhost
    password is empty

[IMPORTANT] Check PostgreSQL password before setup!

Input this command to finish setup:
  cd live
  RAILS_ENV=production bundle exec rake mastodon:setup

EOF

