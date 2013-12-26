require 'test/unit'

class MyTest < Test::Unit::TestCase

  def setup
    ActiveResource::Base.include_root_in_json = true
    setup_response # find me in abstract_unit
    @original_person_site = Person.site
  end

  def teardown
    Person.site = @original_person_site
  end

  def test_new_val_assignment
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    assert addy.street_changed?
  end

  def test_changes_apply_on_save
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    assert addy.street_changed?
    addy.save
    assert !addy.street_changed?
    assert_equal "54321 Lane", addy.street
  end

  def test_changes_apply_on_update_attribute
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.expects(:update).returns(true)
    addy.update_attribute(:street, "54321 Lane")
    assert !addy.street_changed?
  end

  def test_changes_apply_on_update_attributes
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.expects(:update).returns(true)
    addy.update_attributes(:street => "54321 Lane")
    assert !addy.street_changed?
  end

  def test_change_back_an_attribute
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    addy.street = "12345 Street"
    assert !addy.street_changed?
  end

  def test_change_back_and_change_again_an_attribute
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    addy.street = "12345 Street"
    addy.street = "54321 Lane"
    assert addy.street_changed?
  end

  def test_change_back_and_forth_an_attribute
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    addy.street = "12345 Street"
    addy.street = "54321 Lane"
    addy.street = "12345 Street"
    assert !addy.street_changed?
  end

  def test_changed_attributes_encoding
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    assert addy.street_changed?
    StreetAddress.partial_writes = true
    assert_equal(JSON.parse(addy.encode), {"address" => { "street" => "54321 Lane" }})
  end

  def test_changed_attributes_encoding_when_changes_are_reverted
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    addy.street = "12345 Street"
    assert !addy.street_changed?
    StreetAddress.partial_writes = true
    assert_equal(JSON.parse(addy.encode), {"address" => {}})
  end

end