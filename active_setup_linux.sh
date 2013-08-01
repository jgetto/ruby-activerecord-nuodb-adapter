#!/bin/bash
#Script to set up activerecord tests on Ubuntu

#installing dependencies
# sudo apt-get update
# sudo apt-get install libtool libxml2 openssl sqlite
# sudo apt-get install rbenv
# sudo apt-get install ruby-build

echo "eval \"\$(rbenv init -)\"" >> ~/.bash_profile

# rbenv install 1.9.3-p392
# rbenv global 1.9.3-p392
# rbenv rehash
eval "$(rbenv init -)"

# sudo gem list | cut -d" " -f1 | xargs gem uninstall -aIx
# gem install bundler

# Writes to .bash_profile
echo "export NUODB_ROOT=/opt/nuodb/bin
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm" #  Load RVM function" >> ~/.bash_profile

cd ~/
mkdir tmpy
git clone https://github.com/nuodb/ruby-nuodb.git ~/tmpy/ruby-nuodb-latest
cd ~/tmpy/ruby-nuodb-latest
bundle
rbenv rehash

cd ~/tmpy/ruby-nuodb-latest
chmod 777 nuodb.gemspec
sed -i '/README.rdoc/d' ./nuodb.gemspec #Removes README.rdoc to resolve rake errors
gem build nuodb.gemspec
#rake clean build
#cd pkg
sudo gem install nuodb-1.0.2.gem

#Getting the driver
# git clone https://github.com/nuodb/ruby-activerecord-nuodb-adapter.git ~/tmpy/ruby-activerecord-nuodb-adapter-latest
# cd ~/tmpy/ruby-activerecord-nuodb-adapter-latest
# bundle
# rbenv rehash
# rake clean build
# cd pkg
# gem install activerecord-nuodb-adapter-1.0.3.gem #Make robust

#Getting rails
git clone https://github.com/rails/rails.git ~/tmpy/rails-latest
cd ~/tmpy/rails-latest
git checkout v3.2.8
bundle
rbenv rehash
cd activerecord

echo "if ENV['NUODB_AR']
    gem 'activerecord-nuodb-adapter'
end" >> ~/tmpy/rails-latest/Gemfile

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
" >> ~/tmpy/rails-latest/activerecord/test/config.example.yml

sed -i 's/%w( mysql mysql2 postgresql/%w( nuodb mysql mysql2 postgresql/g' Rakefile

echo "gem 'activerecord-nuodb-adapter'" >> ~/tmpy/rails-latest/Gemfile
bundle install

export GEM_PATH=/home/travis/.rvm/gems/ruby-1.9.3-p448

#RUBYLIB="~/tmpy/rails-latest/activerecord/test/cases:$RUBYLIB"
#export RUBYLIB


# Helpful information, make sure that NuoDB is running

# Starting NuoDB
#java -jar /opt/nuodb/jar/nuoagent.jar --broker &
#/opt/nuodb/bin/nuodb --chorus test --password bar --dba-user cloud --dba-password user --verbose debug --archive /var/tmp/nuodb --initialize --force &
#/opt/nuodb/bin/nuodb --chorus test --password bar --dba-user cloud --dba-password user &

# Running Tests
#cd /tmp/rails-latest/activerecord
#ARCONN=nuodb ruby -Itest test/cases/base_test.rb

