# frozen_string_literal: true

require "abstract_unit"

class CollectionTest < ActiveSupport::TestCase
  def setup
    @collection = ActiveResource::Collection.new
  end
end

class BasicCollectionTest < CollectionTest
  def test_collection_respond_to_first_or_create
    assert @collection.respond_to?(:first_or_create)
  end

  def test_collection_respond_to_first_or_initialize
    assert @collection.respond_to?(:first_or_initialize)
  end

  def test_first_or_create_without_resource_class_raises_error
    assert_raise(RuntimeError) { @collection.first_or_create }
  end

  def test_first_or_initialize_without_resource_class_raises_error
    assert_raise(RuntimeError) { @collection.first_or_initialize }
  end

  def respond_to_where
    assert @collection.respond_to?(:where)
  end
end

class PaginatedCollection < ActiveResource::Collection
  attr_accessor :next_page
  def parse_response(parsed)
    @elements = parsed["results"]
    @next_page = parsed["next_page"]
  end
end

class PaginatedPost < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.collection_parser = "PaginatedCollection"
end

class ReduxCollection < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.collection_parser = PaginatedCollection
end


class CollectionInheritanceTest < ActiveSupport::TestCase
  def setup
    @post = { id: 1, title: "Awesome" }
    @post_even_more = { id: 1, title: "Awesome", subtitle: "EvenMore" }
    @posts_hash = { "results" => [@post], :next_page => "/paginated_posts.json?page=2" }
    @posts = @posts_hash.to_json
    @posts2 = { "results" => [@post.merge(id: 2)], :next_page => nil }.to_json

    @empty_posts = { "results" => [], :next_page => nil }.to_json
    @new_post = { id: nil, title: nil }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/paginated_posts.json", {}, @posts
      mock.get    "/paginated_posts/new.json", {}, @new_post
      mock.get    "/paginated_posts.json?page=2", {}, @posts
      mock.get    "/paginated_posts.json?title=test", {}, @empty_posts
      mock.get    "/paginated_posts.json?page=2&title=Awesome", {}, @posts
      mock.get    "/paginated_posts.json?subtitle=EvenMore&title=Awesome", {}, @posts
      mock.get    "/paginated_posts.json?title=notfound", {}, nil, 404
      mock.get    "/paginated_posts.json?title=internalservererror", {}, nil, 500
      mock.post   "/paginated_posts.json", {}, nil
    end
  end

  def test_setting_collection_parser
    assert_kind_of PaginatedCollection, PaginatedPost.find(:all)
  end

  def test_setting_collection_parser_resource_class
    assert_equal PaginatedPost, PaginatedPost.where(page: 2).resource_class
  end

  def test_setting_collection_parser_query_params
    assert_equal({ page: 2 }, PaginatedPost.where(page: 2).query_params)
  end

  def test_custom_accessor
    assert_equal PaginatedPost.find(:all).call.next_page, @posts_hash[:next_page]
  end

  def test_first_or_create
    post = PaginatedPost.where(title: "test").first_or_create
    assert post.valid?
  end

  def test_first_or_initialize
    post = PaginatedPost.where(title: "test").first_or_initialize
    assert post.valid?
  end

  def test_where
    posts = PaginatedPost.where(page: 2)
    next_posts = posts.where(title: "Awesome")
    assert_kind_of PaginatedCollection, next_posts
  end

  def test_where_lazy_chain
    expected_request = ActiveResource::Request.new(
      :get,
      "/paginated_posts.json?subtitle=EvenMore&title=Awesome",
      nil,
      { "Accept" => "application/json" }
    )
    posts = PaginatedPost.where(title: "Awesome").where(subtitle: "EvenMore")
    assert_not posts.requested?
    assert_equal 0, ActiveResource::HttpMock.requests.count { |r| r == expected_request }
    # Call twice to ensure the request is only made once
    posts.to_a
    posts.to_a
    assert_equal 1, ActiveResource::HttpMock.requests.count { |r| r == expected_request }
    assert posts.requested?
  end

  def test_where_lazy_chain_with_no_results
    posts = PaginatedPost.where(title: "notfound")
    assert_not posts.requested?
    assert_equal [], posts.to_a
    assert posts.requested?
  end

  def test_where_lazy_chain_internal_server_error
    posts = PaginatedPost.where(title: "internalservererror")
    assert_not posts.requested?
    assert_raise ActiveResource::ServerError do
      posts.to_a
    end
    assert posts.requested?
  end

  def test_refresh
    expected_request = ActiveResource::Request.new(
      :get,
      "/paginated_posts.json?page=2",
      @posts,
      { "Accept" => "application/json" }
    )
    posts = PaginatedPost.where(page: 2)

    assert_not posts.requested?
    posts.to_a
    assert posts.requested?
    assert_equal 1, ActiveResource::HttpMock.requests.count { |r| r == expected_request }
    posts.refresh
    assert_equal 2, ActiveResource::HttpMock.requests.count { |r| r == expected_request }
    assert posts.requested?
  end

  def test_call
    expected_request = ActiveResource::Request.new(
      :get,
      "/paginated_posts.json?page=2",
      @posts,
      { "Accept" => "application/json" }
    )
    posts = PaginatedPost.where(page: 2)

    assert_not posts.requested?
    assert_kind_of PaginatedCollection, posts.call
    assert posts.requested?
    assert_equal 1, ActiveResource::HttpMock.requests.count { |r| r == expected_request }
  end
end
