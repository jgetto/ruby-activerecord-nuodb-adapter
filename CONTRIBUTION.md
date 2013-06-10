# Contributing to the Ruby ActiveRecord NuoDB Adapter

## BUILDING THE GEM

To compile and test run this command:

    rake clean build

## INSTALLING THE GEM

    gem install activerecord-nuodb-adapter

Or from the source tree:

    gem install pkg/activerecord-nuodb-adapter-1.0.1.gem

Or you can do this using Rake:

    rake clean build uninstall install

## TESTING THE GEM

Start up a minimal chorus as follows:

    java -jar ${NUODB_ROOT}/jar/nuoagent.jar --broker &
    ${NUODB_ROOT}/bin/nuodb --chorus test --password bar --dba-user dba --dba-password baz &

Create a user in the database:

    ${NUODB_ROOT}/bin/nuosql test@localhost --user dba --password baz
    > create user cloud password 'user';
    > exit

Run the tests:

    rake test

## PUBLISHING THE GEM

### TAGGING

Tag the product using tags per the SemVer specification; our tags have a
v-prefix:

    git tag -a v1.0.1 -m "SemVer Version: v1.0.1"
    git push --tags

If you make a mistake, take it back quickly:

    git tag -d v1.0.1
    git push origin :refs/tags/v1.0.1

### PUBLISHING

Here are the commands used to publish:

    gem push pkg/activerecord-nuodb-adapter-1.0.1.gem

## INSPECTING THE GEM

It is often useful to inspect the contents of a Gem before distribution. To do
this you dump the contents of a gem thus:

    gem unpack pkg/activerecord-nuodb-adapter-1.0.1.gem

## RUNNING ACTIVE RECORD COMPLIANCE TEST SUITES

Install both the NuoDB Ruby Gem and the NuoDB ActiveRecord Adapter Gem:

    gem install nuodb
    gem install activerecord-nuodb-adapter

You may need to uninstall an earlier version to ensure you only have the
version you want to install:

    gem uninstall activerecord-nuodb-adapter

Run equivalent commands to the following to set up your environment:

    export NUODB_AR=1
    export NUODB_ROOT=/Users/rbuck/tmp/nuodb
    export PATH=${NUODB_ROOT}/bin:${PATH}

Start up NuoDB as follows:

    java -jar ${NUODB_ROOT}/jar/nuoagent.jar --broker &
    ${NUODB_ROOT}/bin/nuodb --chorus arunit --password bar --dba-user dba --dba-password baz --force &

Configure your RVM environment:

    cd rails
    bundle install

Run the test suite as follows:

    cd activerecord
    ARCONN=nuodb ruby -Itest test/cases/base_test.rb

