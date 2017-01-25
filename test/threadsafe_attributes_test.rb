class ThreadsafeAttributesTest < ActiveSupport::TestCase

  class TestClass
    include ThreadsafeAttributes
    threadsafe_attribute :safeattr
  end

  setup do
    @tester = TestClass.new
  end

  test "#threadsafe attributes work in a single thread" do
    refute @tester.safeattr_defined?
    assert_nil @tester.safeattr
    @tester.safeattr = "a value"
    assert @tester.safeattr_defined?
    assert_equal "a value", @tester.safeattr
  end

  test "#threadsafe attributes inherit the value of the main thread" do
    @tester.safeattr = "a value"
    Thread.new do
      assert @tester.safeattr_defined?
      assert_equal "a value", @tester.safeattr
    end.join
    assert_equal "a value", @tester.safeattr
  end

  test "#changing a threadsafe attribute in a thread does not affect the main thread" do
    @tester.safeattr = "a value"
    Thread.new do
      @tester.safeattr = "a new value"
      assert_equal "a new value", @tester.safeattr
    end.join
    assert_equal "a value", @tester.safeattr
  end

  test "#threadsafe attributes inherit the value of the main thread when value is nil/false" do
    @tester.safeattr = false
    Thread.new do
      assert @tester.safeattr_defined?
      assert_equal false, @tester.safeattr
    end.join
    assert_equal false, @tester.safeattr
  end

  test "#changing a threadsafe attribute in a thread sets an equal value for the main thread, if no value has been set" do
    refute @tester.safeattr_defined?
    assert_nil @tester.safeattr
    Thread.new do
      @tester.safeattr = "value from child"
      assert_equal "value from child", @tester.safeattr
    end.join
    assert @tester.safeattr_defined?
    assert_equal "value from child", @tester.safeattr
  end

  test "#threadsafe attributes can retrieve non-duplicable from main thread" do
    @tester.safeattr = :symbol_1
    Thread.new do
      assert_equal :symbol_1, @tester.safeattr
    end.join
  end

  unless RUBY_PLATFORM == 'java'
    test "threadsafe attributes can be accessed after forking within a thread" do
      reader, writer = IO.pipe
      @tester.safeattr = "a value"
      Thread.new do
        fork do
          reader.close
          writer.print(@tester.safeattr)
          writer.close
        end
      end.join
      writer.close
      assert_equal "a value", reader.read
      reader.close
    end
  end
end
