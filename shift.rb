require 'rubygems'
require 'sinatra'
require 'slim'
require 'sinatra/activerecord'
require 'time'
require 'json'
require_relative 'calendar.rb'

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
  
  def adjust_factor(staffing,delta)
		from, to = Calendar.week(staffing.shift.from)
		losers = []
		winners = []
		Staffing.includes(:shift).where('shifts.from' => from...to, :qualification => staffing.qualification, :area => staffing.area).where.not(:employee_count  => 0).each do | s |
			w = s.employee_count * s.shift.working_hours
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
  Shift.where('"from" <= ? AND "to" >= ?',@calendar.to,@calendar.from).includes(:staffings => [:qualification , :assignments, :area ]).order('areas.name').each do | shift | 
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
  openshift = Shift.includes(:staffings => [:qualification , :assignments, :area  ]).where('"from" <= ? AND "to" >?',@calendar.to,@calendar.from).where('staffings.area_id' => @user.areas,'staffings.qualification_id' => @user.qualification.id).where.not('staffings.employee_count' => 0)
  @user.assignments.includes(:staffing => [ :shift, :area ]).where('shifts.from'  => (@calendar.from-365*24*60*60)...@calendar.to).where('shifts.to'  => @calendar.from...(@calendar.to+365*24*60*60)).each do | assignment |
    shift = assignment.staffing.shift
    @calendar.add(shift.from,shift.to,assignment)
    openshift = openshift.where.not('"from" < ? AND "to" > ?',shift.to,shift.from)
  end
  openshift.each do | shift |
  	@calendar.add(shift.from,shift.to,shift)
  end
  from = @calendar.from.to_date
  from = from-(from.mday-1)
  to = from.next_month
  @wage = 0.0
  @hours = 0.0
  @user.assignments.includes(:staffing => [ :shift ]).where('shifts.from'  => from...to).each do | assignment |
    shift = assignment.staffing.shift
    @wage += assignment.factor * @user.hourly_wage * shift.working_hours
    @hours += shift.working_hours
  end
  slim :assignment
end



put "/assignment/:id" do 
  @user = current_user
  staffing = Staffing.find(params[:id])
  raise "No more places available" if staffing.employee_count == 0 
  @user.assignments.create(:staffing => staffing,:factor => staffing.current_factor)
  staffing.employee_count -= 1  
  staffing.save
  adjust_factor(staffing,0.01)
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
