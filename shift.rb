require 'rubygems'
require 'sinatra'
require 'sinatra/streaming'
require 'slim'
require 'sinatra/activerecord'
require 'time'
require 'date'
require 'json'
require 'pdfkit'
require_relative 'gnatt.rb'
require_relative 'plan.rb'
require 'bcrypt'
require 'ostruct'
require 'securerandom'

class User <ActiveRecord::Base
  include BCrypt

  has_many   :staffings
  has_many   :employments
  belongs_to :qualification
  has_many   :organization, :through => :employments
  def name()
    self.firstname + " " + self.lastname
  end

  def password
    @password ||= Password.new(password_hash)
  end

  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end
end

class Calendar < ActiveRecord::Base
  belongs_to :user
  before_save :default_values
  def default_values
    self.token ||= SecureRandom.hex
  end
end

class Employment <ActiveRecord::Base
  EMPLOYEE = 1
  TEAM_MANAGER = 2
  MANAGER = 4
  belongs_to :organization
  belongs_to :user
  def role_str()
    return "Manager" if ( role & MANAGER == MANAGER )
    return "Team Manager" if ( role & TEAM_MANAGER == TEAM_MANAGER )
    return "Employee" if ( role & EMPLOYEE == EMPLOYEE )
  end
  def self.roles()
    [
      OpenStruct.new(id: EMPLOYEE, name: "Employee"),
      OpenStruct.new(id: TEAM_MANAGER, name: "Team Manager"),
      OpenStruct.new(id: MANAGER, name: "Manager")
    ]
  end
end

class Organization <ActiveRecord::Base
  has_many  :teams
  has_many  :shifts
  has_many  :employments
  has_many  :users, :through => :employments
  def self.mine(user)
    self.joins(:employments).where( employments: {user_id: user.id})
  end
  def self.managed_by(user)
    self.joins(:employments).where( employments: {user_id: user.id, role: Employment::MANAGER})
  end
  def teams_owned_by(user)
    self.teams.includes(team_members: {team_members: :employment}).where(team_members: { employment: {user_id: user.id}, role: TeamMember::OWNER})
  end
  def is_manager(user)
    self.employments.where( employments: {user_id: user.id, role: Employment::MANAGER}).count > 0
  end
end

class Team <ActiveRecord::Base
  has_many  :staffings
  has_many  :team_members
  has_many  :employments, :through => :team_members
  belongs_to :organization
  def is_owned_by?(user)
    self.team_members.includes(:employment).where( employments: {user_id: user.id}, role: TeamMember::OWNER).count > 0 ||
      self.organization.is_manager(user)
  end
end

class TeamMember < ActiveRecord::Base
  MEMBER = 1
  PLANNER = 2
  OWNER = 4
  belongs_to :team
  belongs_to :employment
  def role_str()
    return "Owner" if ( role & OWNER == OWNER )
    return "Planner" if ( role & PLANNER == PLANNER )
    return "Member" if ( role & MEMBER == MEMBER )
  end
  def self.roles()
    [
      OpenStruct.new(id: MEMBER, name: "Member"),
      OpenStruct.new(id: PLANNER, name: "Planner"),
      OpenStruct.new(id: OWNER, name: "Owner")
    ]
  end
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

after do
  ActiveRecord::Base.connection.close
end

before do
  content_type :html, 'charset' => 'utf-8'
end

helpers do
  def current_user()
    user = nil
    begin
      user = User.find(session[:user])
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
      plan = Plan.new(@range)
      team.employments.includes(:user).each { | employment | plan.add_employment(employment)}
      @plans << OpenStruct.new(team: team, plan: plan, writable:  (!print && team.is_owned_by?(@user)))
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

get "/logout" do
  session.delete(:user)
  redirect url("/login")
end

get "/about" do
  @referer = params[:referer] || url("/")
  slim :about
end

get "/users/me" do
  @user = current_user
  slim :user
end

post "/users/me/password" do
  @user = current_user
  password_old = params[:password_old]
  password = params[:password]
  password_confirm = params[:password_confirm]
  p password_old
  p password
  p password_confirm
  raise "Invalid old password" unless @user.password == password_old 
  raise "Password doesn't match" unless password == password_confirm
  @user.password = password
  @user.save
  redirect request.referer
end

get "/users" do
  @user = current_user
  @users = User.all
  slim :users
end

get "/calendars/:token" do
  user = Calendar.where(:token => params[:token]).first.user
  content_type "text/calendar"
  headers "content-disposition" => "inline; filename=Schicht.ics"
  stream do |out|
    out.puts "BEGIN:VCALENDAR"
    out.puts "VERSION:2.0"
    out.puts "METHOD:PUBLISH"
    user.staffings.order(:date).includes(:shift, team: :organization).where("date > ?",Date.today.prev_month).each do | staffing |
      t0 = Time.new(staffing.date.year,staffing.date.month, staffing.date.day)
      [ [ staffing.shift.from1, staffing.shift.to1 , 0] , [ staffing.shift.from2, staffing.shift.to2, 1 ] ].each do | t |
        if t[0]
          out.puts "BEGIN:VEVENT"
          out.puts "UID:#{staffing.id}/#{t[2]}"
          out.puts "SUMMARY:#{staffing.team.organization.name} #{staffing.team.name}: #{staffing.shift.abbrev} "
          out.puts "DTSTART:#{(t0 + t[0]).strftime("%Y%m%dT%H%M%S")}"
          out.puts "DTEND:#{(t0 + t[1]).strftime("%Y%m%dT%H%M%S")}"
          out.puts "DTSTAMP:#{(t0 + t[0]).strftime("%Y%m%dT%H%M%S")}"
          out.puts "END:VEVENT"
        end
      end
    end
    out.puts "END:VCALENDAR"
  end
end

post "/calendars" do
  user = current_user
  calendar = Calendar.where(:user => user).first || Calendar.create(:user => user)
  redirect request.referer
end

get "/signup" do
  @params = {}
  slim :signup
end

post "/signup" do
  begin
    password = params.delete('password')
    password_confirm = params.delete('password_confirm')
    raise "Password doesn't match" if password != password_confirm
    raise "User already exists" if User.where(:email => params[:email]).first
    user = User.new(params)
    user.password = password
    user.save
    session[:user] = user.id
    redirect url("/")
  rescue Exception => exc
    @exception = exc
    @params = params
    return slim :signup
  end
  redirect request.referer
end

post "/login" do
  @email = params[:email]
  @password = params[:password]
  begin
    user  = User.where(:email => @email).first
    raise "Invalid user #{@email}" unless user && user.password == params[:password]
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
  user = @organization.users.find(params[:user_id])
  shift = Shift.find_by(:abbrev => params[:value])
  team = Team.find(params[:team_id])
  date = Date.parse(params[:date])
  staffing = nil
  if params[:old_value] == ''
    shift || halt(400, "Invalid shift ID " + params[:value])
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
  @teams = @organization.teams.order(:name)
  slim :teams
end


get "/:organization/employments" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @is_manager = @organization.is_manager(@user)
  @employments = @organization.employments.includes(:user).order('users.firstname')
  slim :employments
end

get "/:organization/employments/invite" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  halt(403) unless @organization.is_manager(@user)
  @params = params
  @params[:level] = 100
  @params[:role] = Employment::EMPLOYEE
  slim :employments_invite
end

post "/:organization/employments" do
  @user = current_user
  @organization = Organization.managed_by(@user).find(params[:organization])
  @organization.employments.create role: params[:role], user_id: params[:user_id], level: params[:level].to_f / 100.0
  redirect url("/#{@organization.id}/employments")
end

delete "/:organization/employments/:id" do
  @user = current_user
  @organization = Organization.managed_by(@user).find(params[:organization])
  employment = @organization.employments.find(params[:id])
  TeamMember.where(:employment => employment).destroy
  employment.destroy
  redirect request.referer
end

get "/:organization/teams/:id" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @team = @organization.teams.find(params[:id])
  slim :team
end

post "/:organization/team_members" do
  team = Team.find(params[:team_id])
  halt(403) unless team.is_owned_by?(current_user)
  employment = Organization.find(params[:organization]).employments.find(params[:employment_id])
  team.team_members.create employment: employment, role: params[:role]
  redirect request.referer
end

delete "/:organization/team_members/:id" do
  team_member = TeamMember.find(params[:id])
  halt(403) unless team_member.team.is_owned_by?(current_user)
  team_member.destroy
  redirect request.referer
end
