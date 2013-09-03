#!/bin/bash
#Script to set up activerecord tests on Ubuntu

#Getting rails
echo "=== Getting Rails Source ==="
git clone https://github.com/rails/rails.git ~/rails-latest
cd ~/rails-latest
git checkout v3.2.13

echo "=== Apply NuoDB Specific Settings ==="

echo "
  nuodb:
    arunit:
      host: localhost
      database: test@localhost
      username: cloud
      password: user
      schema: test
    arunit2:
      host: localhost
      database: test@localhost
      username: cloud
      password: user
      schema: test
" >> ~/rails-latest/activerecord/test/config.example.yml

cp ~/rails-latest/activerecord/test/config.example.yml ~/rails-latest/activerecord/test/config.yml

sed -i 's/%w( mysql mysql2 postgresql/%w( nuodb mysql mysql2 postgresql/g' Rakefile

echo "gem 'activerecord-nuodb-adapter'" >> ~/rails-latest/Gemfile

echo "=== Finished Setting up AR tests ==="

# Running Tests
#cd /tmp/rails-latest/activerecord
#ARCONN=nuodb ruby -Itest test/cases/base_test.rb

