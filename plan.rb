require 'time'

class PlanRow
  attr_reader :user, :working_hours
  def initialize(user,range)
    @user = user
    @range = range
    @data = Array.new(range.last-range.first)
    @working_hours = 0.0
  end
  def []=(date,shift)
    @data[date-@range.first] = shift
    @working_hours += shift.working_hours
  end
  def each(&block)
    @range.each do |t|
      block.call(@data[t-@range.first],t)
    end
  end
end

class Plan
  attr_reader :range

  def initialize(date)
    case date
    when String
      from = Date.parse(date)
    when Time
      from = date.to_date
    when Date
      from = date
    else
      from = Date.today
    end
    @range = Plan.range(from)
    @table = []
    @rows = {}
  end
  
  def self.range(t)
    t0 = t.to_date
    t0 = t0 - ( t0.day - 1)
    return t0...t0.next_month
  end
  
  def days()
    (0...7).map { |i | @from+i*SECONDS_PER_DAY }
  end
  
  def each_header(&block)
    @range.each do | date |
      block.call(date)
    end
  end
  
  def add(date,shift,user)
    row = @rows[user.id] ||= @table.length
    @table[row] ||=  PlanRow.new(user,@range)
    @table[row][date] = shift
  end
  
  def each_row(&block)
    @table.each &block
  end
  
end
