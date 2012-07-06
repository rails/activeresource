require File.expand_path('../../load_paths', __FILE__)

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'minitest/autorun'
require 'active_resource'
require 'active_support'
require 'active_support/test_case'
require 'setter_trap'
require 'active_support/logger'

ActiveResource::Base.logger = ActiveSupport::Logger.new("#{File.dirname(__FILE__)}/debug.log")

def setup_response
  matz_hash = { 'person' => { :id => 1, :name => 'Matz' } }

  @default_request_headers = { 'Content-Type' => 'application/json' }
  @matz  = matz_hash.to_json
  @matz_xml  = matz_hash.to_xml
  @david = { :person => { :id => 2, :name => 'David' } }.to_json
  @greg  = { :person => { :id => 3, :name => 'Greg' } }.to_json
  @addy  = { :address => { :id => 1, :street => '12345 Street', :country => 'Australia' } }.to_json
  @rick  = { :person => { :name => "Rick", :age => 25 } }.to_json
  @joe    = { :person => { :id => 6, :name => 'Joe', :likes_hats => true }}.to_json
  @people = { :people => [ { :person => { :id => 1, :name => 'Matz' } }, { :person => { :id => 2, :name => 'David' } }] }.to_json
  @people_david = { :people => [ { :person => { :id => 2, :name => 'David' } }] }.to_json
  @addresses = { :addresses => [{ :address => { :id => 1, :street => '12345 Street', :country => 'Australia' } }] }.to_json
  @post  = {:id => 1, :title => 'Hello World', :body => 'Lorem Ipsum'}.to_json
  @post_two  = {:id => 2, :title => 'Hello World', :body => 'Lorem Ipsum'}.to_json
  @posts = [{:id => 1, :title => 'Hello World', :body => 'Lorem Ipsum'},{:id => 2, :title => 'Second Post', :body => 'Lorem Ipsum'}].to_json
  @comments = [{:id => 1, :post_id => 1, :content => 'Interesting post'},{:id => 2, :post_id => 1, :content => 'I agree'}].to_json
  @comments_two = [{:id => 3, :post_id => 2, :content => 'Interesting post'},{:id => 4, :post_id => 2, :content => 'I agree'}].to_json

  # - deep nested resource -
  # - Luis (Customer)
  #   - JK (Customer::Friend)
  #     - Mateo (Customer::Friend::Brother)
  #       - Edith (Customer::Friend::Brother::Child)
  #       - Martha (Customer::Friend::Brother::Child)
  #     - Felipe (Customer::Friend::Brother)
  #       - Bryan (Customer::Friend::Brother::Child)
  #       - Luke (Customer::Friend::Brother::Child)
  #   - Eduardo (Customer::Friend)
  #     - Sebas (Customer::Friend::Brother)
  #       - Andres (Customer::Friend::Brother::Child)
  #       - Jorge (Customer::Friend::Brother::Child)
  #     - Elsa (Customer::Friend::Brother)
  #       - Natacha (Customer::Friend::Brother::Child)
  #     - Milena (Customer::Friend::Brother)
  #
  @luis = {
    :customer => {
      :id => 1,
      :name => 'Luis',
      :friends => [{
        :name => 'JK',
        :brothers => [
          {
            :name => 'Mateo',
            :children => [{ :name => 'Edith' },{ :name => 'Martha' }]
          }, {
            :name => 'Felipe',
            :children => [{ :name => 'Bryan' },{ :name => 'Luke' }]
          }
        ]
      }, {
        :name => 'Eduardo',
        :brothers => [
          {
            :name => 'Sebas',
            :children => [{ :name => 'Andres' },{ :name => 'Jorge' }]
          }, {
            :name => 'Elsa',
            :children => [{ :name => 'Natacha' }]
          }, {
            :name => 'Milena',
            :children => []
          }
        ]
      }],
      :enemies => [{:name => 'Joker'}],
      :mother => {:name => 'Ingeborg'}
    }
  }.to_json
  # - resource with yaml array of strings; for ARs using serialize :bar, Array
  @marty = <<-eof.strip
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <person>
      <id type=\"integer\">5</id>
      <name>Marty</name>
      <colors type=\"yaml\">---
    - \"red\"
    - \"green\"
    - \"blue\"
    </colors>
    </person>
  eof

  @startup_sound = {
    :sound => {
      :name => "Mac Startup Sound", :author => { :name => "Jim Reekes" }
    }
  }.to_json
  
  @product = {id: 1, name: 'Rails book'}.to_json
  @inventory = {status: 'Sold Out', total: 10, used: 10}.to_json

  ActiveResource::HttpMock.respond_to do |mock|
    mock.get    "/people/1.json",               {}, @matz
    mock.get    "/people/1.xml",                {}, @matz_xml
    mock.get    "/people/2.xml",                {}, @david
    mock.get    "/people/5.xml",                {}, @marty
    mock.get    "/people/Greg.json",            {}, @greg
    mock.get    "/people/6.json",               {}, @joe
    mock.get    "/people/4.json",               { 'key' => 'value' }, nil, 404
    mock.put    "/people/1.json",               {}, nil, 204
    mock.delete "/people/1.json",               {}, nil, 200
    mock.delete "/people/2.xml",                {}, nil, 400
    mock.get    "/people/99.json",              {}, nil, 404
    mock.post   "/people.json",                 {}, @rick, 201, 'Location' => '/people/5.xml'
    mock.get    "/people.json",                 {}, @people
    mock.get    "/people/1/addresses.json",     {}, @addresses
    mock.get    "/people/1/addresses/1.json",   {}, @addy
    mock.get    "/people/1/addresses/2.xml",    {}, nil, 404
    mock.get    "/people/2/addresses.json",     {}, nil, 404
    mock.get    "/people/2/addresses/1.xml",    {}, nil, 404
    mock.get    "/people/Greg/addresses/1.json", {}, @addy
    mock.put    "/people/1/addresses/1.json",   {}, nil, 204
    mock.delete "/people/1/addresses/1.json",   {}, nil, 200
    mock.post   "/people/1/addresses.json",     {}, nil, 201, 'Location' => '/people/1/addresses/5'
    mock.get    "/people/1/addresses/99.json",  {}, nil, 404
    mock.get    "/people//addresses.xml",       {}, nil, 404
    mock.get    "/people//addresses/1.xml",     {}, nil, 404
    mock.put    "/people//addresses/1.xml",     {}, nil, 404
    mock.delete "/people//addresses/1.xml",     {}, nil, 404
    mock.post   "/people//addresses.xml",       {}, nil, 404
    mock.head   "/people/1.json",               {}, nil, 200
    mock.head   "/people/Greg.json",            {}, nil, 200
    mock.head   "/people/99.json",              {}, nil, 404
    mock.head   "/people/1/addresses/1.json",   {}, nil, 200
    mock.head   "/people/1/addresses/2.json",   {}, nil, 404
    mock.head   "/people/2/addresses/1.json",    {}, nil, 404
    mock.head   "/people/Greg/addresses/1.json", {}, nil, 200
    # customer
    mock.get    "/customers/1.json",             {}, @luis
    # sound
    mock.get    "/sounds/1.json",                {}, @startup_sound
    # post
    mock.get    "/posts.json",                   {}, @posts
    mock.get    "/posts/1.json",                 {}, @post
    mock.get    "/posts/1/comments.json",        {}, @comments
    mock.get    "/api/posts/2.json",             {}, @post_two
    mock.get    "/api/posts/2/comments.json",    {}, @comments_two
    # products
    mock.get '/products/1.json', {}, @product
    mock.get '/products/1/inventory.json', {}, @inventory
  end

  Person.user = nil
  Person.password = nil
end
