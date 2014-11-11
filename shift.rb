require 'rubygems'
require 'sinatra'
require 'slim'
require 'sinatra/activerecord'
require 'time'
require 'json'

class Employee <ActiveRecord::Base
  has_many :assignments
  has_many :leaves
  belongs_to :qualification
  has_and_belongs_to_many :areas
end

class Leave <ActiveRecord::Base
  belongs_to :employee
end

class Area <ActiveRecord::Base
  has_and_belongs_to_many :employees
  has_many :staffings
end

class Qualification <ActiveRecord::Base
  has_many :employees
  has_many :staffings
end

class Assignment <ActiveRecord::Base
  belongs_to :employee
  belongs_to :staffing
end

class Shift <ActiveRecord::Base
  has_many :staffings
end

class Staffing <ActiveRecord::Base
  belongs_to :area
  belongs_to :shift
  belongs_to :qualification
  has_many :assignments
end


class Calendar
  FIRST_DAY = 1
  attr_reader :days, :hours, :from

  def initialize(date)
    from = date  ? Time.parse(date) : Time.now
    from = from.to_date
    @from = from - ( from.wday - FIRST_DAY)
    @days = @from..(@from+7)
    @hours = 0...48
    @table = []
    for i in @hours
      @table[i] =  [ "","","","","","","" ]
    end
  end
  
  def add(from,to,entry)
    column = (from.to_date.wday + 7 - FIRST_DAY) % 7
    row = (from.hour * 60 + from.min) / 30
    rowe =  (to.hour * 60 + to.min) / 30
    @table[row][column] = entry
    for i in (row+1)...rowe
      @table[i][column] = nil
    end
  end
  
  def get(day,hour)
    column = day-@from
    row = hour
    @table[row][column]
  end
end

enable :sessions
set :bind, '0.0.0.0'
set :database, "sqlite3:shift.db"
set :session_secret, "sRfBLNNJ0F/gaWpmjXasda0WKw5Q="


ActiveRecord::Base.logger.level = 3
ActiveRecord::Migrator.migrate(File.join(File.dirname(__FILE__),"db/migrate"), nil)
ActiveRecord::Base.logger = Logger.new(STDOUT)

helpers do
  def current_user()
    user = nil
    begin
      user = Employee.find(session[:user])
    rescue => ex
    end
    redirect "/login?referrer=#{CGI.escape(env['REQUEST_URI'])}" unless user
    user
  end
end


get "/login" do
  @referrer = params[:referrer] || "/"
  slim :login
end

post "/login" do
  @username = params[:username]
  @password = params[:password]
  begin
    user  = Employee.where(:email => @username).first
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
  slim :index
end

get "/shifts" do
  @user = current_user
  content_type "application/json"
  from = Time.parse(params[:start])
  to = Time.parse(params[:end])
  Shift.where(:from => from..to).includes(:staffings => [:qualification , :assignments, :area ]).order('areas.name').map do | shift | 
    @shift = shift
    { 'start' => shift.from, 'end' => shift.to , 'html' => (slim :shift, :layout => false)}
  end.to_json
end

get "/shifts2" do
  @user = current_user
  
  @calendar = Calendar.new(params[:date])
  Shift.where(:from => @calendar.days).includes(:staffings => [:qualification , :assignments, :area ]).order('areas.name').each do | shift | 
    @calendar.add(shift.from,shift.to,shift)
  end
  slim :shift2
end

get "/assignment" do 
  @user = current_user
  slim :assignment
end

get "/assignment/shifts" do 
  @user = current_user
  from = Time.parse(params[:start])
  to = Time.parse(params[:end])
  entries = []
  ranges = []
  myshift = @user.assignments.includes(:staffing => [ :shift, :area ]).where('shifts.from' => from..to)
  openshift = Shift.includes(:staffings => [:qualification , :assignments, :area  ]).where(:from => from..to, 'staffings.area_id' => @user.areas,'staffings.qualification_id' => @user.qualification.id).where.not('staffings.employee_count' => 0)
  myshift.each do | assignment |
    @assignment = assignment
    shift = assignment.staffing.shift
    entries <<  { 'title' => "#{assignment.staffing.area.name}", 'start' => shift.from, 'end' => shift.to ,  'html' => (slim :assignment_delete, :layout => false) }
    openshift = openshift.where.not(:from => (shift.from...shift.to))
  end
  openshift.each do | shift |
     @shift = shift
     entries <<  { 'start' => shift.from, 'end' => shift.to , 'color' => '#B40404', 'html' =>  (slim :assignment_create, :layout => false)  }
  end
  entries.to_json
end


put "/assignment/:id" do 
  @user = current_user
  staffing = Staffing.find(params[:id])
  @user.assignments.create(:staffing => staffing,:factor => staffing.current_factor)
  staffing.employee_count -= 1
  staffing.save
  redirect request.referrer
end

delete "/assignment/:id" do 
  @user = current_user
  Assignment.find(params[:id]).delete
  redirect request.referrer
end


get "/employee/info" do
  from = Time.parse(params[:date])
  from = Time.new(from.year,from.month,1,0,0,0);
  to = (from.to_date.next_month-1)
  to = Time.new(to.year,to.month,to.day,23,59,59)
  @user = current_user
  @wage = 0.0
  @hours = 0.0
  @user.assignments.includes(:staffing => [:shift]).where('shifts.from' => (from...to)).each do | assignment |
    @wage += assignment.factor * @user.hourly_wage * assignment.staffing.shift.working_hours
    @hours += assignment.staffing.shift.working_hours
  end
  slim :employee_info, :layout => false
end
