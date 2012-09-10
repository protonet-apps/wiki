require 'sinatra'
require 'haml'
require 'rdiscount'
require 'sequel'
require 'logger'

if ENV.key? 'DATABASE_URL'
  DB = Sequel.connect ENV['DATABASE_URL']
  raise 'Not migrated' unless DB.table_exists?(:repos)
elsif ENV['RACK_ENV'] != 'production'
  DB = Sequel.sqlite
  require './migrate'
else
  raise 'Running production mode without a database'
end
DB.loggers << Logger.new(STDOUT) if ENV['RACK_ENV'] != 'production'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end


post '*' do
  pass unless params[:__method]
  call env.merge('REQUEST_METHOD' => params[:__method])
end


get '/' do
  @pages = DB[:pages].join(:versions, :id => :version_id).all
  
  haml :index, :format => :html5
end

get '/new' do
  haml :new, :format => :html5
end

get '/:name' do |name|
  @page = DB[:pages].first(:name => name)
  pass unless @page
  @version = DB[:versions].first(:id => @page[:version_id])
  
  haml :show, :format => :html5
end

get '/:name/versions' do |name|
  @page = DB[:pages].first(:name => name)
  pass unless @page
  @versions = DB[:versions].where(:page_id => @page[:id]).order(:created_at.desc).all
  
  haml :history, :format => :html5
end

get '/:name/versions/new' do |name|
  @page = DB[:pages].first(:name => name)
  pass unless @page
  @version = DB[:versions].first(:id => @page[:version_id])
  
  haml :edit, :format => :html5
end

get '/:name/versions/:version_id' do |name, version_id|
  @page = DB[:pages].first(:name => name)
  @version = @page && DB[:versions].first(:page_id => @page[:id], :id => version_id)
  pass unless @version
  
  haml :show, :format => :html5
end


put '/:name' do |name|
  pass unless params[:title] && params[:body]
  @page = DB[:pages].first(:name => name)
  pass unless @page
  
  version_id = DB[:versions].insert({
    :page_id => @page[:id],
    :user_id => 0,
    :title => params[:title],
    :body => params[:body],
    :created_at => Time.now
  })
  
  DB[:pages].where(:id => @page[:id]).update(:version_id => version_id)
  
  redirect "/#{@page[:name]}"
end

post '/' do
  pass unless params[:name] && params[:title] && params[:body]
  
  page_id = DB[:pages].insert({
    :name => params[:name],
    :created_at => Time.now
  })
  
  version_id = DB[:versions].insert({
    :page_id => page_id,
    :user_id => 0,
    :title => params[:title],
    :body => params[:body],
    :created_at => Time.now
  })
  
  DB[:pages].where(:id => page_id).update(:version_id => version_id)
  
  redirect "/#{params[:name]}"
end
