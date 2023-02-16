# frozen_string_literal: true

class InheritingHashTest < ActiveSupport::TestCase
  def setup
    @parent = ActiveResource::InheritingHash.new({ override_me: "foo", parent_key: "parent_value" })
    @child = ActiveResource::InheritingHash.new(@parent)
    @child[:override_me] = "bar"
    @child[:child_only] = "baz"
  end

  def test_child_key_overrides_parent_key
    assert_equal "bar", @child[:override_me]
  end

  def test_parent_key_available_on_lookup
    assert_equal "parent_value", @child[:parent_key]
  end

  def test_conversion_to_regular_hash_includes_parent_keys
    hash = @child.to_hash

    assert_equal 3, hash.keys.length
    assert_equal "parent_value", hash[:parent_key]
  end
end
