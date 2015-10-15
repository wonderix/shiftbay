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
  has_many   :teams, :through => :team_members
  def name()
    self.firstname + " " + self.lastname
  end
end

class Organization <ActiveRecord::Base
  has_many  :teams
  has_many  :shifts
  has_many  :groups
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


ActiveRecord::Base.logger.level = 3
ActiveRecord::Migrator.migrate(File.join(ROOT,"db/migrate"), nil)
ActiveRecord::Base.logger = Logger.new(STDOUT)

load File.join(ROOT,"db/seeds.rb") if Organization.count == 0

helpers do
  def current_user()
    user = nil
    begin
      # user = User.find(session[:user])
      user = User.find_by(lastname: "Kramer")
    rescue => ex
      p ex
    end
    redirect "#{url("/login")}?referrer=#{CGI.escape(env['REQUEST_URI'])}" unless user
    user
  end
  
  def calendar(calendar,url,&block)
  	@calendar = calendar
  	@url = url
  	@block = block
  	slim :calendar, :layout => false
  end
  
  def adjust_factor(staffing,delta)
		from, to = Calendar.week(staffing.shift.from)
		losers = []
		winners = []
		Staffing.includes(:shift).where('shifts.from' => from...to, :qualification => staffing.qualification, :team => staffing.team).where.not(:user_count  => 0).each do | s |
			w = s.user_count * s.shift.working_hours
			if s.shift.from.hour == staffing.shift.from.hour
				losers << [ s , w ]
			else
				winners << [ s , w ]
			end
		end
		sum = 0.0
		losers.each do | staffing, w |
			sum += w * delta
			staffing.current_factor -= w * delta
			staffing.save
		end
		p sum
		sum_weight = 0.0
		winners.each do | staffing, w |
			sum_weight += w
		end
		sum /= sum_weight
		winners.each do | staffing, w |
			staffing.current_factor += sum * w
			staffing.save
		end
  end
  def get_plan(options = {})
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
    slim :plan, options
  end
end

after do
  ActiveRecord::Base.connection.close
end

get "/login" do
  @referrer = params[:referrer] || url("/")
  slim :login
end

get "/about" do
  @referrer = params[:referrer] || url("/")
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
    redirect(params[:referrer])
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
  html = get_plan(:layout => :layout_pdf)
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
  @organization.teams.each do | team |
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

get "/:organization/teams/:id" do
  @user = current_user
  @organization = Organization.mine(@user).find(params[:organization])
  @team = @organization.teams.find(params[:id])
  slim :team
end
