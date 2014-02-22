class ThreadsafeAttributesTest < ActiveSupport::TestCase

  class TestClass
    include ThreadsafeAttributes
    threadsafe_attribute :safeattr
  end

  setup do
    @tester = TestClass.new
  end

  test "threadsafe attributes work in a single thread" do
    refute @tester.safeattr_defined?
    assert_nil @tester.safeattr
    @tester.safeattr = "a value"
    assert @tester.safeattr_defined?
    assert_equal "a value", @tester.safeattr
  end

  test "threadsafe attributes inherit the value of the main thread" do
    @tester.safeattr = "a value"
    Thread.new do
      assert @tester.safeattr_defined?
      assert_equal "a value", @tester.safeattr
    end.join
    assert_equal "a value", @tester.safeattr
  end

  test "writing a threadsafe attribute in a thread does not affect the main thread" do
    @tester.safeattr = "a value"
    Thread.new do
      @tester.safeattr = "a new value"
      assert_equal "a new value", @tester.safeattr
    end.join
    assert_equal "a value", @tester.safeattr
  end

  test "modifying a threadsafe attribute in a thread does not affect the main thread" do
    @tester.safeattr = {a: 1}
    Thread.new do
      @tester.safeattr[:a] = 2
      assert_equal 2, @tester.safeattr[:a]
    end.join
    assert_equal 1, @tester.safeattr[:a]
  end

end
