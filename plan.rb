require 'time'



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
    block.call(nil)
    @range.each do | date |
      block.call(date)
    end
  end
  
  def add(date,shift,user)
    row = @rows[user.id] ||= @table.length
    col = date - @range.begin
    @table[row] ||=  [user]
    @table[row][col+1] = shift
  end
  
  def each_row(&block)
    @table.each &block
  end
  
  def each_col(row,&block)
    block.call(row[0])
    @range.each do | date |
      block.call(row[date-@range.first+1],date,row[0])
    end
  end
end
