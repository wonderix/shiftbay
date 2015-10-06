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


class ShiftRow
  attr_reader :range
  def initialize(range,date_range)
    @range = range
    @date_range = date_range
    @data = Array.new(@date_range.last-@date_range.first)
  end
  def add(date)
    col = date-@date_range.first
    @data[col] = @data[col].to_i + 1
  end
  
  def each(&block)
    @date_range.each do |t|
      block.call(@data[t-@date_range.first],t)
    end
  end
end

class Plan
  attr_reader :range
  TIME_SLOT = 7200
  TIME_SLOT_RANGE = (6*3600/TIME_SLOT)...(20*3600/TIME_SLOT)

  def initialize(range)
    @range = range
    @table = []
    @rows = {}
    @time_rows = Array.new(24*3600/TIME_SLOT)
  end
  
  
  def self.range(date)
    case date
    when String
      t = date.to_date
    when Date
      t = date
    else
      t = Date.today
    end
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
  
  def add_user(user)
    index = @rows[user.id] ||= @table.length
    row = @table[index] ||=  PlanRow.new(user,@range)
  end
  
  def add(date,shift,user)
    row = add_user(user)
    [ [shift.from1,shift.to1 ] , [shift.from2,shift.to2 ] ].each do | from, to |
      next unless from
      first = [ from/TIME_SLOT, TIME_SLOT_RANGE.first].max
      last =  [ to/TIME_SLOT, TIME_SLOT_RANGE.last].min
      for t in first...last
        time_row = @time_rows[t] ||= ShiftRow.new((@range.first.to_time+t*TIME_SLOT)...(@range.first.to_time+(t+1)*TIME_SLOT),@range)
        time_row.add(date)
      end
    end
    row[date] = shift
  end
  
  def each_row(&block)
    @table.each &block
  end

  def each_time_row(&block)
    @time_rows.each do | k |
      block.call(k) if k
    end
  end

end
