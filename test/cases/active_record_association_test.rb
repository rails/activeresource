# frozen_string_literal: true

require "active_record"
require "active_resource/associations/active_record"

class ActiveRecordAssociationTest < ActiveSupport::TestCase
  setup do
    setup_response # find me in abstract_unit

    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )
    ActiveRecord::Schema.define do
      self.verbose = false

      create_table :test_records, force: true do |t|
        t.string :name
        t.belongs_to :person
        t.belongs_to :book
        t.timestamps
      end
    end

    ActiveRecord::Base.extend(ActiveResource::Associations::ActiveRecord)

    class TestRecord < ActiveRecord::Base
      belongs_to_resource :person
      belongs_to_resource :book, class_name: "Product"
    end
  end

  def test_belongs_to_resource
    record = TestRecord.create(name: "test", person_id: 1)
    assert_equal record.person.name, "Matz"
  end

  def test_belongs_to_resource_with_class_name
    record = TestRecord.create(name: "test", person_id: 1, book_id: 1)
    assert_equal record.book.name, "Rails book"
  end
end
