require 'rubygems'
require 'data_mapper'
require 'dm-sqlite-adapter'
require 'bcrypt' 

DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")

class User
  include DataMapper::Resource
  include BCrypt

  property :id, Serial, :key => true
  property :username, String, :length => 3..50, :unique => true 
  property :password, BCryptHash
  property :nation_slug, String, :length => 3..100
  property :api_token, String, :length => 3..100
    
    has n, :sites
    
    def authenticate(attempted_password)
        if self.password == attempted_password
            true
        else
            false
        end
    end   
end

class Site
    include DataMapper::Resource

    property :site_id, Serial, :key => true
    property :nation_slug, String, :length => 3..100
    property :api_token, String, :length => 3..100
    
    belongs_to :user
end

DataMapper.finalize
DataMapper.auto_upgrade!