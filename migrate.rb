unless Object.const_defined? 'DB'
  raise 'Not given a database to migrate' unless ENV.key? 'DATABASE_URL'
  
  require 'sequel'
  require 'logger'

  DB = Sequel.connect ENV['DATABASE_URL']
  DB.loggers << Logger.new(STDOUT) if ENV['RACK_ENV'] != 'production'
end

unless DB.table_exists?(:pages) && DB.table_exists?(:versions)
  DB.create_table :pages do
    primary_key :id

    String   :name,        :null => false, :unique => true
    constraint(:name_min_length) { length(name) > 0 }

    DateTime :created_at, :null => false
    index    :created_at
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
  
  DB.alter_table :pages do
    add_foreign_key :version_id, :versions
    add_index       :version_id
  end

  # Some test data
  if ENV['RACK_ENV'] != 'production'
    ['home', 'api', 'ui', 'db'].each do |seed|
      DB[:pages] << {:name => seed, :created_at => Time.now}
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

    DB[:pages].where(:id => 1).update(:version_id => 1)
    DB[:pages].where(:id => 2).update(:version_id => 4)
    DB[:pages].where(:id => 3).update(:version_id => 6)
    DB[:pages].where(:id => 4).update(:version_id => 7)
  end
end

