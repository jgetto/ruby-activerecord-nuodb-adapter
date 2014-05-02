# Ruby ActiveRecord NuoDB Adapter

[<img src="https://secure.travis-ci.org/nuodb/ruby-activerecord-nuodb-adapter.png?branch=master" alt="Continuous Integration Status" />](http://travis-ci.org/nuodb/ruby-activerecord-nuodb-adapter)
[<img src="https://gemnasium.com/nuodb/ruby-activerecord-nuodb-adapter.png?travis" alt="Dependency Status" />](https://gemnasium.com/nuodb/ruby-activerecord-nuodb-adapter)
[<img src="https://codeclimate.com/github/nuodb/ruby-activerecord-nuodb-adapter.png" />](https://codeclimate.com/github/nuodb/ruby-activerecord-nuodb-adapter)
 
The Ruby ActiveRecord NuoDB Adapter enables the ActiveRecord ORM to work with [NuoDB](http://nuodb.com/). Together with the [Ruby NuoDB driver](https://github.com/nuodb/ruby-nuodb), this gem allows for NuoDB backed Rails applications.

Note: At this time the Ruby ActiveRecord NuoDB Adapter does not support Windows.

## Getting Started

1.  If you haven't already, [Download and Install NuoDB](http://nuodb.com/download-nuodb/)

2.  Add the ActiveRecord NuoDB Adapter to your Gemfile

        gem 'activerecord-nuodb-adapter'

3.  Use bundler to install

        bundle install

4.  Use the NuoDB Manager to create your database by starting a Storage
    Manager (SM) and Transaction Engine (TE)

        java -jar /opt/nuodb/jar/nuodbmanager.jar --broker localhost --user domain --password bird

        > start process sm host localhost database blog_development archive /var/opt/nuodb/production-archives/blog_development initialize yes
        > start process te host localhost database blog_development options '--dba-user blog --dba-password bl0gPassw0rd'

5.  Update your config/database.yml file

        development:
          adapter: nuodb
          database: blog_development@localhost
          username: blog
          password: bl0gPassw0rd
          schema: blog


## More Information

*   [NuoDB Community Forum](http://www.nuodb.com/community/forum.php)
*   [NuoDB Online Documentation](http://www.nuodb.com/community/documentation.php)


## Contributing

See [Contribution](CONTRIBUTION.md) for information about contributing to
the Ruby ActiveRecord NuoDB Adapter.

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/48a7777cbd0353a0b8e4cb380f2e530f "githalytics.com")](http://githalytics.com/nuodb/ruby-activerecord-nuodb-adapter)
