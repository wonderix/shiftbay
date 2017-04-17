require 'time'

class PlanRow
  attr_reader :user, :working_hours, :level_of_employment, :team
  def initialize(user,team,range,level_of_employment)
    @user = user
    @team = team
    @range = range
    @level_of_employment = level_of_employment
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


class StaffingRow
  attr_reader :range, :data, :date_range
  
  def initialize(range,date_range,data = nil)
    @range = range
    @date_range = date_range
    @data = data || Array.new(@date_range.last-@date_range.first)
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
  
  def self.merge(row1,row2)
    return row1.clone unless row2
    return row2.clone unless row1
    if row1.data == row2.data
      return StaffingRow.new(row1.range.first...row2.range.last,row1.date_range,row1.data)
    end
    return nil
  end
end

class Plan
  attr_reader :range, :working_hours, :read_only, :team
  TIME_SLOT = 1800
  TIME_SLOT_RANGE = (0*3600/TIME_SLOT)...(24*3600/TIME_SLOT)

  def initialize(range,team)
    @range = range
    @table = []
    @rows = {}
    @team = team
    @time_rows = Array.new(24*3600/TIME_SLOT)
    @working_hours = 0
    @range.each { | date| @working_hours += 40.0/6.0 unless date.sunday? }
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
    
  def range()
    return @range
  end
  
  def days()
    (0...7).map { |i | @from+i*SECONDS_PER_DAY }
  end
  
  def each_header(&block)
    @range.each do | date |
      block.call(date)
    end
  end
  
  def add_employment(employment, team = nil)
    add_user(employment.user,employment.level,team)
  end

  def add_user(user,level_of_employment,team)
    team ||= @team
    id = "#{team.id}:#{user.id}"
    index = @rows[id] ||= @table.length
    row = @table[index] ||=  PlanRow.new(user,team,@range,level_of_employment)
  end
  
  def add(staffing)
    date = staffing.date
    shift = staffing.shift
    user = staffing.user
    row = add_user(user,0.0,staffing.team)
    [ [shift.from1,shift.to1 ] , [shift.from2,shift.to2 ] ].each do | from, to |
      next unless from
      first = [ from/TIME_SLOT, TIME_SLOT_RANGE.first].max
      last =  [ to/TIME_SLOT, TIME_SLOT_RANGE.last].min
      for t in first...last
        time_row = @time_rows[t] ||= StaffingRow.new((@range.first.to_time+t*TIME_SLOT)...(@range.first.to_time+(t+1)*TIME_SLOT),@range)
        time_row.add(date)
      end
    end
    row[date] = shift
  end
  
  def each_row(&block)
    @table.sort!{ | x , y | result = x.user.firstname <=> y.user.firstname; result == 0 ? x.team.name <=> y.team.name : result }
    @table.each &block
  end

  def each_shift(&block)
    @shifts.values.each &block
  end

  def each_time_row(&block)
    p = nil
    @time_rows.each do | k |
      if k
        p = k unless p
        if p.data == k.data
          p = StaffingRow.new(p.range.first...k.range.last,k.date_range,k.data)
        else
          block.call(p)
          p = k
        end
      end
    end
    block.call(p) if p
  end

end
