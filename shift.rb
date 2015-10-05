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
  has_many :assignments
  has_many :leaves
  belongs_to :qualification
  belongs_to :organization
end


class Organization <ActiveRecord::Base
  has_many :users
end

class Qualification <ActiveRecord::Base
  has_many :users
  has_many :staffings
end


class Shift <ActiveRecord::Base
  has_many :staffings
end

class Staffing <ActiveRecord::Base
  belongs_to :organization
  belongs_to :shift
  belongs_to :user
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

helpers do
  def current_user()
    user = nil
    begin
      user = User.find(session[:user])
    rescue => ex
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
		Staffing.includes(:shift).where('shifts.from' => from...to, :qualification => staffing.qualification, :organization => staffing.organization).where.not(:user_count  => 0).each do | s |
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
  redirect url("/plan")
end

post "/staffing" do 
  user = User.find(params[:user_id])
  shift = Shift.find_by(:abbrev => params[:value])
  date = Date.parse(params[:date])
  staffing = nil
  if params[:old_value] == ''
    shift || raise(ActiveRecord::RecordNotFound)
    staffing = Staffing.create(:shift => shift, :user => user, :date => date)
  else   
    old_shift = Shift.find_by(:abbrev => params[:old_value]) || raise(ActiveRecord::RecordNotFound)
    staffing = Staffing.find_by(:user => user, :date => date, :shift => old_shift) || raise(ActiveRecord::RecordNotFound)
    if shift
      staffing.update(:shift => shift)
    else
      staffing.destroy()
    end
  end
  ""
end

get "/plan" do
  @plan = Plan.new(params[:date])
  Staffing.includes(:user,:shift).where(:date => @plan.range).each do | staffing |
    @plan.add(staffing.date,staffing.shift,staffing.user)
  end
  slim :plan
end

get "/plan.pdf" do
  @plan = Plan.new(params[:date])
  Staffing.includes(:user,:shift).where(:date => @plan.range).each do | staffing |
    @plan.add(staffing.date,staffing.shift,staffing.user)
  end
  headers[ 'content-type'] = 'application/pdf'
  # headers[ 'content-disposition'] = "attachment; filename=plan.pdf"
  html = slim(:plan, :layout => false)
  kit = PDFKit.new(html)
  kit.to_pdf
end

get "/gnatt" do
  @gnatt = Gnatt.new(params[:date])
  Staffing.includes(:user,:shift).where(:date => (@gnatt.date-1)..@gnatt.date).each do | staffing |
    time = staffing.date.to_time
    shift = staffing.shift
    from1 = time + shift.from1
    to1 = time + shift.to1
    @gnatt.add(from1,to1,staffing.user.name)
    if shift.from2
      from2 = time + shift.from2
      to2 = time + shift.to2
      @gnatt.add(from2,to2,staffing.user.name)
    end
  end
  slim :gnatt
end

