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

Event = Struct.new("Event",:rows,:data)

class Calendar
  FIRST_DAY = 1
  attr_reader :days, :hours, :from

  def initialize(date)
    from = date  ? Time.parse(date) : Time.now
    from = from.to_date
    @from = from - ( from.wday - FIRST_DAY)
    @days = @from...(@from+7)
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
    @table[row][column] = Event.new(rowe-row,entry)
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
  def calendar(calendar,url,&block)
  	@calendar = calendar
  	@url = url
  	@block = block
  	slim :calendar, :layout => false
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
  redirect url("/shift")
end

get "/shift" do
  @user = current_user
  @calendar = Calendar.new(params[:date])
  Shift.where(:from => @calendar.days).includes(:staffings => [:qualification , :assignments, :area ]).order('areas.name').each do | shift | 
    @calendar.add(shift.from,shift.to,shift)
  end
  slim :shift
end



get "/assignment" do 
  @user = current_user
  @calendar = Calendar.new(params[:date])
  @user = current_user
  ranges = []
  myshift = 
  @wage = 0.0
  @hours = 0.0
  openshift = Shift.includes(:staffings => [:qualification , :assignments, :area  ]).where(:from => @calendar.days, 'staffings.area_id' => @user.areas,'staffings.qualification_id' => @user.qualification.id).where.not('staffings.employee_count' => 0)
  @user.assignments.includes(:staffing => [ :shift, :area ]).where('shifts.from' => @calendar.days).each do | assignment |
    shift = assignment.staffing.shift
    @calendar.add(shift.from,shift.to,assignment)
    openshift = openshift.where.not(:from => (shift.from...shift.to))
    @wage += assignment.factor * @user.hourly_wage * shift.working_hours
    @hours += shift.working_hours
  end
  openshift.each do | shift |
  	@calendar.add(shift.from,shift.to,shift)
  end
  slim :assignment
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
  slim :employee_info, :layout => false
end
