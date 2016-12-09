require 'abstract_unit'
require 'fixtures/person'
require 'fixtures/custom_path'

class CustomPathTest < ActiveSupport::TestCase
  def setup
    setup_response # find me in abstract_unit

    @accepts = { 'Accept' => 'application/json' }
  end

  def test_parse_non_singleton_resource_with_has_one_makes_get_request_on_child_route
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get '/custom/path/posts/1.json', @accepts, @post
      mock.get '/custom/path/posts/1/author.json', @accepts, @matz
    end

    CustomPath::Post.send(:has_one, :author, class_name: 'CustomPath::Person')

    post = CustomPath::Post.find(1)

    assert post.author.name == ActiveSupport::JSON.decode(@matz)['person']['name']
  end

  def test_parse_resources_with_has_many_makes_get_request_on_nested_route
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get '/custom/path/posts/1.json', @accepts, @post
      mock.get '/custom/path/posts/1/comments.json', @accepts, @comments
    end

    CustomPath::Post.send(:has_many, :comments, class_name: 'CustomPath::Comment')
    post = CustomPath::Post.find(1)
    post.comments.each do |comment|
      assert_kind_of CustomPath::Comment, comment
    end
  end
end
