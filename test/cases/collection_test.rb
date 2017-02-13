class CollectionTest < ActiveSupport::TestCase
  def setup
    @collection = ActiveResource::Collection.new
  end  
end

class BasicCollectionTest < CollectionTest
  def test_collection_respond_to_collect!
    assert @collection.respond_to?(:collect!)
  end

  def test_collection_respond_to_map!
    assert @collection.respond_to?(:map!)
  end

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
  
  def test_collect_bang_modifies_elements
    elements = %w(a b c)
    @collection.elements = elements
    results = @collection.collect! { |i| i + "!" }
    assert_equal results.to_a, elements.collect! { |i| i + "!" }
  end
  
  def test_collect_bang_returns_collection
    @collection.elements = %w(a)
    results = @collection.collect! { |i| i + "!" }
    assert_kind_of ActiveResource::Collection, results
  end

  def respond_to_where
    assert @collection.respond_to?(:where)
  end

end

class PaginatedCollection < ActiveResource::Collection
  attr_accessor :next_page
  def initialize(parsed = {})
    @elements = parsed['results']
    @next_page = parsed['next_page']
  end
end

class PaginatedPost < ActiveResource::Base
  self.site = 'http://37s.sunrise.i:3000'
  self.collection_parser = 'PaginatedCollection'
end

class ReduxCollection < ActiveResource::Base
  self.site = 'http://37s.sunrise.i:3000'
  self.collection_parser = PaginatedCollection
end


class CollectionInheretanceTest < ActiveSupport::TestCase
  def setup
    @post = {:id => 1, :title => "Awesome"}
    @posts_hash = {"results" => [@post], :next_page => '/paginated_posts.json?page=2'}
    @posts = @posts_hash.to_json
    @posts2 = {"results" => [@post.merge({:id => 2})], :next_page => nil}.to_json

    @empty_posts = { "results" => [], :next_page => nil }.to_json
    @new_post = { :id => nil, :title => nil }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    '/paginated_posts.json', {}, @posts
      mock.get    '/paginated_posts/new.json', {}, @new_post
      mock.get    '/paginated_posts.json?page=2', {}, @posts
      mock.get    '/paginated_posts.json?title=test', {}, @empty_posts
      mock.get    '/paginated_posts.json?page=2&title=Awesome', {}, @posts
      mock.post   '/paginated_posts.json', {}, nil
    end
  end
  
  def test_setting_collection_parser
    assert_kind_of PaginatedCollection, PaginatedPost.find(:all)
  end

  def test_setting_collection_parser_resource_class
    assert_equal PaginatedPost, PaginatedPost.where(:page => 2).resource_class
  end

  def test_setting_collection_parser_original_params
    assert_equal({:page => 2}, PaginatedPost.where(:page => 2).original_params)
  end
  
  def test_custom_accessor
    assert_equal PaginatedPost.find(:all).next_page, @posts_hash[:next_page]
  end

  def test_first_or_create
    post = PaginatedPost.where(:title => 'test').first_or_create
    assert post.valid?
  end

  def test_first_or_initialize
    post = PaginatedPost.where(:title => 'test').first_or_initialize
    assert post.valid?
  end

  def test_where
    posts = PaginatedPost.where(:page => 2)
    next_posts = posts.where(:title => 'Awesome')
    assert_kind_of PaginatedCollection, next_posts
  end

end
