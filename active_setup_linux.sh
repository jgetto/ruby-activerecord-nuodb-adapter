#!/bin/bash
#Ubuntu
#installing dependencies
sudo apt-get install libtool libxml2 openssl sqlite
sudo apt-get install rbenv
sudo apt-get install ruby-build

echo "eval \"\$(rbenv init -)\"" >> ~/.bash_profile

rbenv install 1.9.3-p392
rbenv global 1.9.3-p392
rbenv rehash
eval "$(rbenv init -)"

sudo gem list | cut -d" " -f1 | xargs gem uninstall -aIx
gem install bundler

# Writes to .bash_profile
echo "export NUODB_ROOT=/opt/nuodb/bin
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm" #  Load RVM function" >> ~/.bash_profile

git clone https://github.com/nuodb/ruby-nuodb.git ~/Documents/ruby-nuodb-latest
cd ruby-nuodb-latest
bundle
rbenv rehash

sudo chmod 777 nuodb.gemspec
sed -i '/README.rdoc/d' ./nuodb.gemspec #Removes README.rdoc to resolve rake errors
rake clean build
cd pkg
gem install nuodb-1.0.2.gem

cd ~/Documents

#Getting the driver
git clone https://github.com/nuodb/ruby-activerecord-nuodb-adapter.git ~/Documents/ruby-activerecord-nuodb-adapter-latest
cd ~/Documents/ruby-activerecord-nuodb-adapter-latest
bundle
rbenv rehash
rake clean build
cd pkg
gem install activerecord-nuodb-adapter-1.0.3.gem #Make robust

#Getting rails
cd ~/Documents
git clone https://github.com/rails/rails.git ~/Documents/rails-latest
cd ~/Documents/rails-latest
git checkout v3.2.8
bundle
rbenv rehash
cd activerecord

echo "if ENV['NUODB_AR']
    gem 'activerecord-nuodb-adapter'
end" >> ~/Documents/rails-latest/Gemfile

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
" >> ~/Documents/rails-latest/activerecord/test/config.example.yml

sed -i 's/%w( mysql mysql2 postgresql/%w( nuodb mysql mysql2 postgresql/g' Rakefile

echo "gem 'activerecord-nuodb-adapter'" >> ~/Documents/rails-latest/Gemfile
bundle install

#Starting NuoDB
#java -jar /opt/nuodb/jar/nuoagent.jar --broker &
#/opt/nuodb/bin/nuodb --chorus test --password bar --dba-user cloud --dba-password user --verbose debug --archive /var/tmp/nuodb --initialize --force &
#/opt/nuodb/bin/nuodb --chorus test --password bar --dba-user cloud --dba-password user &

#Running Tests
#cd ~/Documents/rails-latest/activerecord
#ARCONN=nuodb ruby -Itest test/cases/base_test.rb

