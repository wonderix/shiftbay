require 'rubygems'
require 'sinatra'
require 'slim'
require 'sinatra/activerecord'
require 'time'
require 'json'

class Employee <ActiveRecord::Base
  has_many :offers
  has_many :leaves
  belongs_to :qualification
  has_and_belongs_to_many :areas
end

class Leave <ActiveRecord::Base
  belongs_to :employee
end

class Area <ActiveRecord::Base
  has_and_belongs_to_many :employees
  has_many :shifts
end

class Qualification <ActiveRecord::Base
  has_many :employees
  has_many :staffings
end

class Offer <ActiveRecord::Base
  belongs_to :employee
  belongs_to :shift
end

class Shift <ActiveRecord::Base
  belongs_to :area
  has_many :staffings
end

class Staffing <ActiveRecord::Base
  belongs_to :shift
  belongs_to :qualification
end


enable :session
set :bind, '0.0.0.0'
set :database, "sqlite3:shift.db"


ActiveRecord::Base.logger.level = 1
ActiveRecord::Migrator.migrate(File.join(File.dirname(__FILE__),"db/migrate"), nil)


get "/" do
  slim :index
end

get "/shifts" do
  content_type "application/json"
  from = Time.parse(params[:start])
  to = Time.parse(params[:end])
  employees = "Ulrich\nMonika\nJulian\nDaniel\nThorsten"
  Shift.where(:from => from..to).map{ | shift | { 'title' => "#{shift.area.name}\n#{employees}", 'start' => shift.from, 'end' => shift.to , 'color' => 'red' } }.to_json
end

