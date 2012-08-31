require 'sinatra'
require 'rdiscount'
require 'sequel'
require 'logger'

DB = if ENV.key? 'DATABASE_URL'
  Sequel.connect ENV['DATABASE_URL']
else
  Sequel.sqlite
end
DB.loggers << Logger.new(STDOUT)

unless DB.table_exists?(:pages) && DB.table_exists?(:versions)
  DB.create_table :pages do
    primary_key :id

    String   :name,        :null => false, :unique => true
    constraint(:name_min_length) { length(name) > 0 }

    DateTime :created_at, :null => false
    index    :created_at
  end

  ['home', 'api', 'ui', 'db'].each do |seed|
    DB[:pages] << {:name => seed, :created_at => Time.now}
  end
  
  DB.create_table :versions do
    primary_key :id
    foreign_key :page_id, :pages, :null => false
    index       :page_id

    Fixnum      :user_id,    :null => false
    index       :user_id
    
    String      :title,       :null => false
    constraint(:title_min_length) { length(title) > 0 }
    String      :body,        :null => false, :text => true
    constraint(:body_min_length)  { length(body) > 0 }

    DateTime    :created_at, :null => false
    index       :created_at
  end

  DB[:versions].multi_insert([
    {:page_id => 1, :user_id => 1, :title => 'Home', :body => 'Welcome to the wiki homepage.', :created_at => Time.now},
    {:page_id => 2, :user_id => 1, :title => 'API docs', :body => 'iframes all the way, man!', :created_at => Time.now},
    {:page_id => 2, :user_id => 2, :title => 'API docs', :body => 'binary all the way, man!', :created_at => Time.now+1},
    {:page_id => 2, :user_id => 1, :title => 'API docs', :body => 'RESTful all the way, man!', :created_at => Time.now+2},
    {:page_id => 3, :user_id => 1, :title => 'UI spec', :body => 'It\'s a GUI interface in Visual Basic that will be capable of tracking an IP address.', :created_at => Time.now},
    {:page_id => 3, :user_id => 2, :title => 'UI spec', :body => 'It\'s a GUI interface in Visual Basic that\'s capable of tracking an IP address.', :created_at => Time.now+1},
    {:page_id => 4, :user_id => 3, :title => 'DB schema', :body => 'There\'s multiple tables', :created_at => Time.now},
  ])
  
  
  DB.alter_table :pages do
    add_foreign_key :version_id, :versions
    add_index       :version_id
  end
  
  DB[:pages].where(:id => 1).update(:version_id => 1)
  DB[:pages].where(:id => 2).update(:version_id => 4)
  DB[:pages].where(:id => 3).update(:version_id => 6)
  DB[:pages].where(:id => 4).update(:version_id => 7)
end

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
