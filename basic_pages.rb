require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra'
require 'json'
require 'nationbuilder'
require 'sinatra/base' 
require 'sinatra/flash'
require 'warden'

require './model' 

class MyApp < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
    
#LOGIN CODE    
use Warden::Manager do |config|
    # Tell Warden how to save our User info into a session. Sessions can only take strings, not Ruby code, we'll store the User's `id`
  config.serialize_into_session{|user| user.id }
    # Now tell Warden how to take what we've stored in the session and get a User from that information.
  config.serialize_from_session{|id| User.get(id) }
  config.scope_defaults :default,
      # "strategies" is an array of named methods with which to attempt authentication. We have to define this later.
  strategies: [:password],
      # The action is a route to send the user to when warden.authenticate! returns a false answer. We'll show this route below.
  action: 'auth/unauthenticated'
    # When a user tries to log in and cannot, this specifies the app to send the user to.
  config.failure_app = self
end
    
Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
end 

Warden::Strategies.add(:password) do
    def valid?
      params['user']['username'] && params['user']['password']
    end

    def authenticate!
      user = User.first(username: params['user']['username'])

      if user.nil?
        throw(:warden, message: "The username you entered does not exist.")
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
          throw(:warden, message: "That's the wrong username and password combination, try again.")
      end
 end
end

@current_user = nil

#ADMIN PORTAL
get '/user_index' do
    if env['warden'].user
    @current_user = env['warden'].user
    @users = User.all
    erb :user_index
    else 
        flash[:error] = env['warden.options'][:message] || "You can't access that page!"
        redirect '/auth/login'
    end
end

#LOGIN PAGE
get '/auth/login' do
    erb :login
end

#LOGIN POST
post '/auth/login' do
    env['warden'].authenticate!
    @current_user = env['warden'].user
    current_username = @current_user[:username]
    if session[:return_to].nil?
    flash[:success] = "Welcome back #{current_username}, you're logged in."
    redirect "/#{current_username}"
    else
    flash[:success] = "Welcome back #{current_username}, you're logged in."
    redirect "/#{current_username}"
end
end

#Unauthenticated LOG-IN
post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path]
    puts env['warden.options'][:attempted_path]
    flash[:error] = env['warden.options'][:message] || "You must log in!"
    redirect '/auth/login'
end

#LOGOUT URL
get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:success] = 'Successfully logged out'
redirect '/'
end

#CREATE NEW USER FORM
get '/create/new/user' do
    erb :create_user
end

#CREATE NEW USER POST
post '/create/new/user' do
    user_test = User.first(username: params['user']['username'])
    if user_test.nil?
        User.create(:username => params['user']['username'], :password => params['user']['password'])
        if env['warden'].authenticate!
            @current_user = env['warden'].user
            flash[:success] = "Welcome #{params['user']['username']}, thanks for joining. You're logged in."
        redirect "/#{params['user']['username']}/create/site"
        else
        flash[:success] = "Welcome #{params['user']['username']}, thanks for joining. Please sign in"
        redirect "/auth/login"
end
    else
flash[:error] = "#{params['user']['username']}, already exists as a username please <a href='/auth/login'>sign in</a> to your existing account or choose a different username."
redirect "/create/new/user"
end
end

#ADD SITES TO USER

get '/:user/create/site' do
    if env['warden'].user
        @current_user = env['warden'].user
        if @current_user[:username] == params[:user] 
            erb :create_user_site
        else
        current_username = @current_user[:username]
        flash[:error] = "You can't access that page, please go to your own sites."
        redirect '/#{current_username}/create/site'
        end
    else
    flash[:error] = "You can't access that page, please log in!"
    redirect '/auth/login'
    end
end
    
#POST SITES TO USER
post '/:user/create/site' do
    @user = User.first(username: params[:user])
    if @user
        @site = Site.new(:nation_slug => params['nation_slug'], :api_token => params['api_token'])
        @user.sites << @site
        if @user.save
            redirect "/#{params[:user]}"
        else
            flash[:error] = "Something went wrong, please try again."
            redirect "/#{params[:user]}/create/site"
        end
    end
end

#USER HOMEPAGE
get '/:user' do
    if env['warden'].user
    @current_user = env['warden'].user
        if @current_user[:username] == params[:user]
            user = User.first(:username => params[:user])
            @sites = user.sites
            @site_count = 0
            @users_sites = []
            @sites.each do |site|
                nation_slug = site.nation_slug
                api_token = site.api_token
                client = NationBuilder::Client.new(nation_slug, api_token, retries: 8)   
                api_results = client.call(:sites, :index)
                @site_count = @site_count + api_results['total']
                @users_sites.push api_results['results']
            end
        erb :user_homepage
        else
        flash[:error] = env['warden'].message || "You can't access that page!"
        redirect '/'
        end
    else 
        flash[:error] = env['warden'].message || "You can't access that page!"
        redirect '/auth/login'
    end
end

get '/' do
    nation_slug = 'organizerkevincoleman'
    api_token = '4319835f09710397c8cd979aea0cc865e3168ea78b0fc874401325e01abbc108'
    client = NationBuilder::Client.new(nation_slug, api_token, retries: 8)   
    result = client.call(:basic_pages, :index, site_slug: 'kevinjamescoleman')['results']
    output = ''
    result.each do |w|
        slug = w['slug']
        headline = w['headline']
        output << "<tr><td><a href='/pages/#{slug}'>#{slug}</a></td><td>#{headline}</td><td><a href='/pages/edit/#{slug}'><i>Edit</i></td></tr>"
end
    erb :index, :locals => {results: output}
end 

get '/pages/:page_slug' do
    nation_slug = 'organizerkevincoleman'
    api_token = '4319835f09710397c8cd979aea0cc865e3168ea78b0fc874401325e01abbc108'
    client = NationBuilder::Client.new(nation_slug, api_token, retries: 8)   
    result = client.call(:basic_pages, :index, site_slug: 'kevinjamescoleman')['results']
    output = ''
    page_result = result.find {|page| page['slug'] == params['page_slug']}
    if page_result != nil
        page_slug_result = page_result['slug']
        page_headline = page_result['headline']
        page_name = page_result['name']
        page_status = page_result['status']
        page_excerpt = page_result['excerpt']
        page_content = page_result['content']
        output << "This page exists. The slug is <strong>#{page_slug_result}</strong>, the page name is #{page_name}, the page headline is #{page_headline}, the status is #{page_status} the excerpt is #{page_excerpt} and the content is below. <br> #{page_content}"
    else
        output << "#{params['page_slug']} is not a page slug."
    end
    erb :page_show, :locals => {results: output}
end  
    
get '/pages/edit/:page_slug' do
    nation_slug = 'organizerkevincoleman'
    api_token = '4319835f09710397c8cd979aea0cc865e3168ea78b0fc874401325e01abbc108'
    client = NationBuilder::Client.new(nation_slug, api_token, retries: 8)   
    result = client.call(:basic_pages, :index, site_slug: 'kevinjamescoleman')['results']
    @edit_page = result.find {|page| page['slug'] == params['page_slug']}
    @title = @edit_page['name']
    erb :page_edit
end

post '/pages/edit/:page_slug' do
    nation_slug = 'organizerkevincoleman'
    api_token = '4319835f09710397c8cd979aea0cc865e3168ea78b0fc874401325e01abbc108'
    client = NationBuilder::Client.new(nation_slug, api_token, retries: 8)   
    result = client.call(:basic_pages, :index, site_slug: 'kevinjamescoleman')['results']
    page_result = result.find {|page| page['slug'] == params['page_slug']}
        if page_result != nil
            page_id = page_result['id']
            page_name = params[:name]
            page_slug = params[:slug]
            page_headline = params[:headline]
            page_title = params[:title]
            page_excerpt = params[:excerpt]
            page_content = params[:content]
            update_page = {
                site_slug: 'kevinjamescoleman',
                id: page_id,
  	             basic_page: {
                    name: page_name,
                    slug: page_slug,
                    headline: page_headline,
                    title: page_title,
                    excerpt: page_excerpt,
                    content: page_content,
                    status: "published",
                     }
}
      client.call(:basic_pages, :update, update_page)
  end
  redirect '/'
end



  run! if app_file == $0
end