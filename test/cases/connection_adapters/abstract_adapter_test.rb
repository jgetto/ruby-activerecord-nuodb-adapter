require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class AbstractAdapterTest < ActiveRecord::TestCase
      attr_reader :adapter

      def setup
        @adapter = AbstractAdapter.new nil, nil
      end

      def test_in_use?
        # FIXME: change to refute in Rails 4.0 / mt
        assert !adapter.in_use?, 'adapter is not in use'
        assert adapter.lease, 'lease adapter'
        assert adapter.in_use?, 'adapter is in use'
      end

      def test_lease_twice
        assert adapter.lease, 'should lease adapter'
        assert !adapter.lease, 'should not lease adapter'
      end

      def test_last_use
        assert !adapter.last_use
        adapter.lease
        assert adapter.last_use
      end

      def test_expire_mutates_in_use
        assert adapter.lease, 'lease adapter'
        assert adapter.in_use?, 'adapter is in use'
        adapter.expire
        assert !adapter.in_use?, 'adapter is in use'
      end

      def test_close
        pool = ConnectionPool.new(Base::ConnectionSpecification.new({}, nil))
        pool.connections << adapter
        adapter.pool = pool

        # Make sure the pool marks the connection in use
        assert_equal adapter, pool.connection
        assert adapter.in_use?

        # Close should put the adapter back in the pool
        adapter.close
        assert !adapter.in_use?

        assert_equal adapter, pool.connection
      end
    end
  end
end
