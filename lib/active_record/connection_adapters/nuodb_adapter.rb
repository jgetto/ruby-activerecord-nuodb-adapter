#
# Copyright (c) 2012, NuoDB, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of NuoDB, Inc. nor the names of its contributors may
#       be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL NUODB, INC. BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
# OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require 'arel/visitors/nuodb'
require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/abstract/database_statements'
require 'active_record/connection_adapters/statement_pool'
require 'active_record/connection_adapters/nuodb/version'
require 'arel/visitors/bind_visitor'
require 'active_support/core_ext/hash/keys'

require 'nuodb'

module ActiveRecord

  class Base

    def self.nuodb_connection(config) #:nodoc:
      config.symbolize_keys!
      unless config[:database]
        raise ArgumentError, "No database file specified. Missing argument: database"
      end
      # supply configuration defaults
      config.reverse_merge! :host => 'localhost'
      config.reverse_merge! :timezone => 'UTC'
      ConnectionAdapters::NuoDBAdapter.new nil, logger, nil, config
    end

  end

  class LostConnection < WrappedDatabaseException
  end

  module ConnectionAdapters

    class NuoDBColumn < Column

      def initialize(name, default, sql_type = nil, null = true, length = nil, precision = nil, scale = nil, options = {})
        @options = options.symbolize_keys

        @name      = name
        @null      = null

        # NuoDB stores fixed point decimal values as 'bigint'
        # Examine the scale to determine the type
        if precision > 0 && sql_type == 'bigint'
          @sql_type  = 'decimal'
          @type      = :decimal
          @precision = precision
          @scale     = scale
        else
          @sql_type  = sql_type
          @type      = simplified_type(sql_type)
          @precision = nil
          @scale     = nil
        end

        # Limit only applies to :string, :text, :binary, and :integer
        # See http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/TableDefinition.html
        if @type =~ /^(string|text|binary|integer)$/ && @sql_type != 'string'
          @limit     = length
        else
          @limit     = nil
        end

        @default   = extract_default(default)
        @primary   = @options[:is_identity] || @options[:is_primary]
        @coder     = nil
      end

      class << self

        def string_to_binary(value)
          "0x#{value.unpack("H*")[0]}"
        end

        def binary_to_string(value)
          value =~ /[^[:xdigit:]]/ ? value : [value].pack('H*')
        end

      end

      def is_identity?
        @options[:is_identity]
      end

      def is_primary?
        @options[:is_primary]
      end

      def is_utf8?
        !!(@sql_type =~ /nvarchar|ntext|nchar/i)
      end

      def is_integer?
        !!(@sql_type =~ /int/i)
      end

      def is_real?
        !!(@sql_type =~ /real/i)
      end

      def sql_type_for_statement
        if is_integer? || is_real?
          sql_type.sub(/\((\d+)?\)/, '')
        else
          sql_type
        end
      end

      def default_function
        @options[:default_function]
      end

      def table_name
        @options[:table_name]
      end

      def table_klass
        @table_klass ||= begin
          table_name.classify.constantize
        rescue StandardError, NameError, LoadError
          nil
        end
        (@table_klass && @table_klass < ActiveRecord::Base) ? @table_klass : nil
      end

      private

      def extract_limit(sql_type)
        case sql_type
          when /^smallint/i
            2
          when /^int/i
            4
          when /^bigint/i
            8
          else
            super
        end
      end

      def simplified_type(field_type)
        case field_type
          when /bit/i then
            :boolean
          when /timestamp/i then
            :timestamp
          when /time/i then
            :time
          when /date/i then
            :date
          when /string/i then
            :text
          else
            super
        end
      end

    end #class NuoDBColumn

    class NuoDBAdapter < AbstractAdapter

      class StatementPool < ConnectionAdapters::StatementPool

        attr_reader :max, :connection

        def initialize(connection, max)
          super
          @cache = Hash.new { |h, pid| h[pid] = {} }
        end

        def each(&block)
          cache.each(&block)
        end

        def key?(key)
          cache.key?(key)
        end

        def [](key)
          cache[key]
        end

        def []=(sql, key)
          while max <= cache.size
            dealloc cache.shift.last[:stmt]
          end
          cache[sql] = key
        end

        def length
          cache.length
        end

        def delete(key)
          dealloc cache[key][:stmt]
          cache.delete(key)
        end

        def clear
          cache.each_value do |hash|
            dealloc hash[:stmt]
          end
          cache.clear
        end

        private

        def cache
          @cache[Process.pid]
        end

        def dealloc(stmt)
          # todo
          #stmt.finish if connection.ping
        end
      end

      def process_id
        Process.pid
      end

      attr_accessor :config, :statements

      class BindSubstitution < Arel::Visitors::NuoDB
        include Arel::Visitors::BindVisitor
      end

      def initialize(connection, logger, pool, config)
        super(connection, logger, pool)
        @visitor = Arel::Visitors::NuoDB.new self
        @config = config.clone
        # prefer to run with prepared statements unless otherwise specified
        if @config.fetch(:prepared_statements) { true }
          @visitor = Arel::Visitors::NuoDB.new self
        else
          @visitor = BindSubstitution.new self
        end
        connect!
      end

      # ABSTRACT ADAPTER #######################################

      # ADAPTER NAME ===========================================

      def adapter_name
        'NuoDB'
      end

      # FEATURES ===============================================

      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_count_distinct?
        true
      end

      def supports_ddl_transactions?
        true
      end

      def supports_bulk_alter?
        false
      end

      def supports_savepoints?
        true
      end

      def supports_index_sort_order?
        true
      end

      def supports_partial_index?
        false
      end

      def supports_explain?
        false
      end

      # CONNECTION MANAGEMENT ==================================

      def reconnect!
        disconnect!
        connect!
        super
      end

      def connect!
        @connection = ::NuoDB::Connection.new(config)
        @statements = StatementPool.new(@connection, @config.fetch(:statement_limit) { 1000 })
        @quoted_column_names, @quoted_table_names = {}, {}
      end

      def disconnect!
        super
        clear_cache!
        raw_connection.disconnect rescue nil
      end

      def reset!
        reconnect!
      end

      def clear_cache!
        @statements.clear
      end

      # SAVEPOINT SUPPORT ======================================

      def create_savepoint
        execute("SAVEPOINT #{current_savepoint_name}")
      end

      def rollback_to_savepoint
        execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
      end

      def release_savepoint
        execute("RELEASE SAVEPOINT #{current_savepoint_name}")
      end

      # EXCEPTION TRANSLATION ==================================

      protected

      LOST_CONNECTION_MESSAGES = [/remote connection closed/i].freeze

      def lost_connection_messages
        LOST_CONNECTION_MESSAGES
      end

      CONNECTION_NOT_ESTABLISHED_MESSAGES = [/can't find broker for database/i, /no .* nodes are available for database/i]

      def connection_not_established_messages
        CONNECTION_NOT_ESTABLISHED_MESSAGES
      end

      def translate_exception(exception, message)
        case message
          when /duplicate value in unique index/i
            RecordNotUnique.new(message, exception)
          when /too few values specified in the value list/i
            # defaults to StatementInvalid, so we are okay, but just to be explicit...
            super
          when *lost_connection_messages
            LostConnection.new(message, exception)
          when *connection_not_established_messages
            ConnectionNotEstablished.new(message)
          #when /violates foreign key constraint/
          #  InvalidForeignKey.new(message, exception)
          else
            super
        end
      end

      # SCHEMA DEFINITIONS #####################################

      public

      def primary_key(table_name)
        # n.b. active record does not support composite primary keys!
        row = exec_query(<<-eosql, 'SCHEMA', [config[:schema], table_name.to_s]).rows.first
          SELECT
            indexfields.field as field_name
          FROM
            system.indexfields AS indexfields
          WHERE
            indexfields.schema = ? AND
            indexfields.tablename = ?
        eosql
        row && row.first.downcase
      end

      def version
        self.class::VERSION
      end

      # SCHEMA STATEMENTS ######################################

      public

      # Bug: (4) methods, see: http://tools/jira/browse/DB-2389

      def change_column(table_name, column_name, type, options = {})
        raise NotImplementedError, "change_column is not implemented"
        #execute("ALTER TABLE #{quote_table_name(table_name)} #{change_column_sql(table_name, column_name, type, options)}")
      end

      def change_column_default(table_name, column_name, default)
        raise NotImplementedError, "change_column_default is not implemented"
        #column = column_for(table_name, column_name)
        #change_column table_name, column_name, column.sql_type, :default => default
      end

      def change_column_null(table_name, column_name, null, default = nil)
        raise NotImplementedError, "change_column_null is not implemented"
        #column = column_for(table_name, column_name)
        #unless null || default.nil?
        #  execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        #end
        #change_column table_name, column_name, column.sql_type, :null => null
      end

      def rename_column(table_name, column_name, new_column_name)
        raise NotImplementedError, "rename_column is not implemented"
        #execute("ALTER TABLE #{quote_table_name(table_name)} #{rename_column_sql(table_name, column_name, new_column_name)}")
      end

      def rename_table(table_name, new_name)
        raise NotImplementedError, "rename_table is not implemented"
        #execute("RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}")
      end
      
      def add_column(table_name, column_name, type, options = {})
        clear_cache!
        add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{quote_column_name(column_name)}"
        add_column_options!(add_column_sql, options)
        execute(add_column_sql)
      end
      
      def remove_index!(table_name, index_name) #:nodoc:
        raise NotImplementedError, "remove_index! is not implemented"
      end

      def rename_index(table_name, old_name, new_name)
        execute("ALTER INDEX #{quote_column_name(old_name)} RENAME TO #{quote_table_name(new_name)}")
      end
      
      def table_exists?(table_name)
        return false unless table_name

        table_name = table_name.to_s.downcase
        schema, table = table_name.split('.', 2)

        unless table
          table = schema
          schema = nil
        end

        tables('SCHEMA', schema).include? table
      end

      def tables(name = 'SCHEMA', schema = nil)
        result = exec_query(<<-eosql, name, [schema || config[:schema]])
          SELECT
            tablename
          FROM
            system.tables
          WHERE
            schema = ?
        eosql
        result.inject([]) do |tables, row|
          row.symbolize_keys!
          tables << row[:tablename].downcase
        end
      end

      # Returns an array of indexes for the given table. Skip primary keys.
      def indexes(table_name, name = nil)

        # the following query returns something like this:
        #
        # INDEXNAME              TABLENAME NON_UNIQUE FIELD     LENGTH
        # ---------------------- --------- ---------- --------- ------
        # COMPANIES..PRIMARY_KEY COMPANIES 0          ID        4
        # COMPANY_INDEX          COMPANIES 1          FIRM_ID   4
        # COMPANY_INDEX          COMPANIES 1          TYPE      255
        # COMPANY_INDEX          COMPANIES 1          RATING    4
        # COMPANY_INDEX          COMPANIES 1          RUBY_TYPE 255

        result = exec_query(<<-eosql, 'SCHEMA', [config[:schema], table_name.to_s])
          SELECT
            indexes.indexname as index_name,
            indexes.tablename as table_name,
            CASE indexes.indextype WHEN 2 THEN 1 ELSE 0 END AS non_unique,
            indexfields.field as field_name,
            fields.length as field_length
          FROM
            system.indexes AS indexes, system.indexfields AS indexfields, system.fields AS fields
          WHERE
            indexes.schema = ? AND
            indexes.tablename = ? AND
            indexes.indexname = indexfields.indexname AND
            indexfields.field = fields.field AND
            indexfields.schema = fields.schema AND
            indexfields.tablename = fields.tablename
        eosql
        indexes = []
        current_index = nil
        result.map do |row|
          row.symbolize_keys!
          index_name = row[:index_name]
          if current_index != index_name
            next if !!(/PRIMARY/ =~ index_name)
            current_index = index_name
            table_name = row[:table_name]
            is_unique = row[:non_unique].to_i == 1
            indexes << IndexDefinition.new(table_name, index_name, is_unique, [], [], [])
          end
          indexes.last.columns << row[:field_name] unless row[:field_name].nil?
          indexes.last.lengths << row[:field_length] unless row[:field_length].nil?
        end
        indexes
      end

      def columns(table_name, name = nil)

        # the following query returns something like this:
        #
        # INDEXNAME              TABLENAME NON_UNIQUE FIELD     LENGTH
        # ---------------------- --------- ---------- --------- ------
        # COMPANIES..PRIMARY_KEY COMPANIES 0          ID        4
        # COMPANY_INDEX          COMPANIES 1          FIRM_ID   4
        # COMPANY_INDEX          COMPANIES 1          TYPE      255
        # COMPANY_INDEX          COMPANIES 1          RATING    4
        # COMPANY_INDEX          COMPANIES 1          RUBY_TYPE 255

        result = exec_query(<<-eosql, 'SCHEMA', [config[:schema], table_name.to_s])
          SELECT
            fields.field as name,
            fields.defaultvalue as default_value,
            datatypes.name as data_type,
            fields.length as length,
            fields.scale as scale,
            fields.precision as precision,
            fields.flags as flags
          FROM
            system.fields AS fields, system.datatypes AS datatypes
          WHERE
            schema = ? AND tablename = ? AND
            datatypes.id = fields.datatype
          ORDER BY fields.fieldposition
        eosql

        columns = []
        result.map do |row|
          row.symbolize_keys!
          columns << NuoDBColumn.new(row[:name].downcase, row[:default_value], row[:data_type], row[:flags].to_i & 1 == 0, row[:length], row[:scale], row[:precision])
        end
        columns
      end

      public

      def native_database_types
        {
            # generic rails types...
            :binary => {:name => 'binary'},
            :boolean => {:name => 'boolean'},
            :date => {:name => 'date'},
            :datetime => {:name => 'timestamp'},
            :decimal => {:name => 'decimal'},
            :float => {:name => 'float', :limit => 8},
            :integer => {:name => 'integer', :limit => 4},
            :primary_key => 'int not null generated by default as identity primary key',
            :string => {:name => 'varchar', :limit => 255},
            :text => {:name => 'string'},
            :time => {:name => 'time'},
            :timestamp => {:name => 'timestamp'},
            # nuodb specific types...
            :char => {:name => 'char'},
            :numeric => {:name => 'numeric(20)'},
        }
      end

      # jruby version -- no original
      def modify_types(tp)
        tp[:primary_key] = 'int not null generated always primary key'
        tp[:boolean] = {:name => 'boolean'}
        tp[:date] = {:name => 'date', :limit => nil}
        tp[:datetime] = {:name => 'timestamp', :limit => nil}
        tp[:decimal] = {:name => 'decimal'}
        tp[:integer] = {:name => 'int', :limit => 4}
        tp[:string] = {:name => 'string'}
        tp[:time] = {:name => 'time', :limit => nil}
        tp[:timestamp] = {:name => 'timestamp', :limit => nil}
        tp
      end

      # jruby version
      # maps logical rails types to nuodb-specific data types.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil)
        case type.to_s
          when 'integer'
            return 'integer' unless limit
            case limit
              when 1..2
                'smallint'
              when 3..4
                'integer'
              when 5..8
                'bigint'
              else
                raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
            end
          when 'timestamp'
            column_type_sql = 'timestamp'
            unless precision.nil?
              case precision
                when 0..9
                  column_type_sql << "(#{precision})"
                else
                  nil
              end
            end
            column_type_sql
          when 'time'
            column_type_sql = 'time'
            unless precision.nil?
              case precision
                when 0..9
                  column_type_sql << "(#{precision})"
                else
                  nil
              end
            end
            column_type_sql
          else
            super
        end
      end

      private

      def split_table_name(table)
        name_parts = table.split '.'
        case name_parts.length
          when 1
            schema_name = config[:schema]
            table_name = name_parts[0]
          when 2
            schema_name = name_parts[0]
            table_name = name_parts[1]
          else
            raise "Invalid table name: #{table}"
        end
        [schema_name, table_name]
      end

      # QUOTING ################################################

      public

      def quote_column_name(name)
        @quoted_column_names[name] ||= "`#{name.to_s.gsub('`', '``')}`"
      end

      def quote_table_name(name)
        @quoted_table_names[name] ||= quote_column_name(name).gsub('.', '`.`')
      end

      def type_cast(value, column)
        return super unless value == true || value == false
        value ? true : false
      end

      def quoted_true
        "'true'"
      end

      def quoted_false
        "'false'"
      end

      def quoted_date(value)
        if value.acts_like?(:time)
          zone_conversion_method = :getutc
          if value.respond_to?(zone_conversion_method)
            value = value.send(zone_conversion_method)
          end
        end
        value.to_s(:db)
      end

      # DATABASE STATEMENTS ####################################

      public

      def select_rows(sql, name = nil)
        exec_query(sql, name).rows
      end
      
      def select_values(sql, name = nil)
        exec_query(sql, name).values
      end

      def outside_transaction?
        nil
      end

      def supports_statement_cache?
        true
      end

      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()
        log('begin transaction', nil) {
          raw_connection.autocommit = false if raw_connection.autocommit?
        }
      end

      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction()
        log('commit transaction', nil) {
          raw_connection.autocommit = true unless raw_connection.autocommit?
          raw_connection.commit
        }
      end

      # Rolls back the transaction (and turns on auto-committing). Must be
      # done if the transaction block raises an exception or returns false.
      def rollback_db_transaction()
        log('rollback transaction', nil) {
          raw_connection.autocommit = true unless raw_connection.autocommit?
          raw_connection.rollback
        }
      end

      def default_sequence_name(table, column)
        result = exec_query(<<-eosql, 'SCHEMA', [table.to_s, column.to_s])
          SELECT generator_sequence FROM system.fields WHERE tablename='#{table}' AND field='#{column}'
        eosql
        result.rows.first.first
      rescue ActiveRecord::StatementInvalid
        "#{table}$#{column}"
      end

      def execute(sql, name = 'SQL')
        log(sql, name) do
          cache = statements[process_id] ||= {
              :stmt => raw_connection.statement
          }
          stmt = cache[:stmt]
          stmt.execute(sql)
        end
      end

      def exec_insert(sql, name, binds)
        exec_query sql, name, binds.map { |col, val| type_cast(val, col) }, true
      end

      def exec_update(sql, name, binds)
        exec_query(sql, name, binds, true)
      end

      def exec_delete(sql, name, binds)
        exec_query(sql, name, binds.map { |col, val| type_cast(val, col) })
      end

      def exec_query(sql, name = 'SQL', binds = [], get_generated_keys = false)
        log(sql, name, binds) do
          if binds.empty?

            cache = statements[process_id] ||= {
                :stmt => raw_connection.statement
            }
            stmt = cache[:stmt]

            results = nil
            if stmt.execute(sql)
              results = convert_results stmt.results
            end
            if get_generated_keys
              generated_keys_result = stmt.generated_keys
              if generated_keys_result.nil? || generated_keys_result.rows.empty?
                @last_inserted_id = nil
              else
                @last_inserted_id = generated_keys_result.rows.last[0]
              end
            end

            results
          else
            cache = statements[sql] ||= {
                :stmt => raw_connection.prepare(sql)
            }
            stmt = cache[:stmt]

            results = nil
            stmt.bind_params binds
            if stmt.execute
              results = convert_results stmt.results
            end
            if get_generated_keys
              generated_keys_result = stmt.generated_keys
              if generated_keys_result.nil? || generated_keys_result.rows.empty?
                @last_inserted_id = nil
              else
                @last_inserted_id = generated_keys_result.rows.last[0]
              end
            end

            results
          end
        end
      end

      def convert_results(results)
        ActiveRecord::Result.new(column_names(results), results.rows)
      end

      def last_inserted_id(result)
        @last_inserted_id
      end

      protected

      def select(sql, name = nil, binds = [])
        exec_query(sql, name, binds.map { |col, val| type_cast(val, col) }).to_a
      end

      private

      def column_names (result)
        return [] if result.nil?
        result.columns.inject([]) do |array, column|
          array << column.name.downcase
        end
      end

    end

  end

end
