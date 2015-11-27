require 'rubygems'
require 'sinatra'
require 'slim'
require 'sinatra/activerecord'
require 'time'
require 'json'
require 'pdfkit'
require_relative 'gnatt.rb'
require_relative 'plan.rb'

class User <ActiveRecord::Base
  has_many   :staffings
  has_many  :team_members
  belongs_to :qualification
  belongs_to :organization
  has_many   :teams, :through => :team_members
  before_create :set_defaults
  scope :employed, -> { where("employed_until > ?", Time.now) }
  def set_defaults
    self.employed_since = Time.now
    self.employed_until = Time.new(2100,1,1)
  end
  def name()
    self.firstname + " " + self.lastname
  end
end

class Organization <ActiveRecord::Base
  has_many  :teams
  has_many  :shifts
  has_many  :groups
  has_many  :users
  def self.mine(user)
    self.joins(groups: :group_members).where( group_members: {user_id: user.id})
  end
end

class Group <ActiveRecord::Base
  MEMBER = 1
  PLANNER = 2
  OWNER = 4
  has_many  :group_members
  has_many  :users, :through => :group_members
  belongs_to :organization
end

class GroupMember < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
end

class Team <ActiveRecord::Base
  has_many  :staffings
  has_many  :team_members
  has_many  :users, :through => :team_members
  belongs_to :organization
end

class TeamMember < ActiveRecord::Base
  belongs_to :team
  belongs_to :user
end

class Qualification <ActiveRecord::Base
  has_many :users
  has_many :staffings
end


class Shift <ActiveRecord::Base
  has_many :staffings
  belongs_to :organization
end

class Staffing <ActiveRecord::Base
  belongs_to :team
  belongs_to :shift
  belongs_to :user
end


PDFKit.configure do |config|
  config.default_options = {
    :page_size => 'A4',
    :print_media_type => true
  }
  # Use only if your external hostname is unavailable on the server.
  config.root_url = "http://localhost"
  config.verbose = true
end


register Sinatra::ActiveRecordExtension

ROOT = File.dirname(File.expand_path(__FILE__))
DB = "sqlite3:#{ROOT}/shift.db"
enable :sessions
set :bind, '0.0.0.0'
set :database, DB
set :session_secret, "sRfBLNNJ0F/gaWpmjXasda0WKw5Q="
use Rack::MethodOverride

ActiveRecord::Base.logger.level = 3
ActiveRecord::Migrator.migrate(File.join(ROOT,"db/migrate"), nil)
ActiveRecord::Base.logger = Logger.new(STDOUT)

load File.join(ROOT,"db/seeds.rb") if Organization.count == 0

before do
  content_type :html, 'charset' => 'utf-8'
end

helpers do
  def current_user()
    user = nil
    begin
      # user = User.find(session[:user])
      user = User.find_by(lastname: "Kramer")
    rescue => ex
      p ex
    end
    redirect "#{url("/login")}?referer=#{CGI.escape(env['REQUEST_URI'])}" unless user
    user
  end
  
  def calendar(calendar,url,&block)
  	@calendar = calendar
  	@url = url
  	@block = block
  	slim :calendar, :layout => false
  end
  
  def get_plan(print = false)
    @user = current_user
    @organization = Organization.mine(@user).find(params[:organization])
    @plans = []
    @range = Plan.range(params[:date])
    @organization.teams.order(:name).each do | team |
      puts team.name
      plan = Plan.new(@range)
      team.users.order(:firstname,:lastname).each { | user | plan.add_user(user)}
      @plans << OpenStruct.new(team: team, plan: plan, writable:  true)
      Staffing.includes(:user,:shift).where(date: plan.range, team: team).each do | staffing |
        plan.add(staffing.date,staffing.shift,staffing.user)
      end
    end
    @print = print
    slim :plan, layout: ( print ? :layout_pdf : :layout)
  end
end

after do
  ActiveRecord::Base.connection.close
end

get "/login" do
  @referer = params[:referer] || url("/")
  slim :login
end

get "/about" do
  @referer = params[:referer] || url("/")
  slim :about
end

get "/user/info" do
  slim :user_info, :layout => false
end

post "/login" do
  @username = params[:username]
  @password = params[:password]
  begin
    user  = User.where(:email => @username).first
    raise "Invalid user #{@username}" unless user
    session[:user] = user.id
    redirect(params[:referer])
  rescue Exception => exc
    @exception = exc
    slim :login
  end  
end

get "/" do
  @user = current_user
  @organizations = Organization.mine(@user)
  slim :orgs
end


post "/:organization/staffing" do 
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  user = User.find(params[:user_id])
  shift = Shift.find_by(:abbrev => params[:value])
  team = Team.find(params[:team_id])
  date = Date.parse(params[:date])
  staffing = nil
  if params[:old_value] == ''
    shift || raise(ActiveRecord::RecordNotFound)
    staffing = Staffing.create(:shift => shift, :user => user, :date => date, :team => team)
  else   
    old_shift = Shift.find_by(:abbrev => params[:old_value]) || raise(ActiveRecord::RecordNotFound)
    staffing = Staffing.find_by(:user => user, :date => date, :shift => old_shift, :team => team) || raise(ActiveRecord::RecordNotFound)
    if shift
      staffing.update(:shift => shift)
    else
      staffing.destroy()
    end
  end
  ""
end

get "/:organization/plan" do
  get_plan
end

get "/:organization/plan.pdf" do
  html = get_plan(true)
  headers[ 'content-type'] = 'application/pdf'
  # headers[ 'content-disposition'] = "attachment; filename=plan.pdf"
  kit = PDFKit.new(html)
  kit.to_pdf
end

get "/:organization/gnatt" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @gnatts = []
  @range = Gnatt.range(params[:date])
  @organization.teams.order(:name).each do | team |
    gnatt = Gnatt.new(@range)
    @gnatts << OpenStruct.new(:team => team, :gnatt => gnatt)
    Staffing.includes(:user,:shift).where(:date => (gnatt.date-1)..gnatt.date, :team => team).each do | staffing |
      time = staffing.date.to_time
      shift = staffing.shift
      from1 = time + shift.from1
      to1 = time + shift.to1
      gnatt.add(from1,to1,staffing.user.name)
      if shift.from2
        from2 = time + shift.from2
        to2 = time + shift.to2
        gnatt.add(from2,to2,staffing.user.name)
      end
    end
  end
  slim :gnatt
end

get "/:organization/teams" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @teams = @organization.teams
  slim :teams
end

get "/:organization/users" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @users = @organization.users
  slim :users
end

post "/:organization/users" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @team = @organization.teams.find(params[:team_id])
  redirect request.referer
end

delete "/:organization/users/:id" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  User.find(params[:id]).update(:employed_until => Time.now)
  redirect request.referer
end

get "/:organization/teams/:id" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @team = @organization.teams.find(params[:id])
  slim :team
end

post "/:organization/team_members" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @team = @organization.teams.find(params[:team_id])
  user = User.find(params[:user_id])
  @team.team_members.create user: user
  redirect request.referer
end

delete "/:organization/team_members/:id" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  TeamMember.find(params[:id]).destroy
  redirect request.referer
end
