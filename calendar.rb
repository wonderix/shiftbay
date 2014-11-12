require 'time'


Event = Struct.new("Event",:rows,:data)

class Calendar
  FIRST_DAY = 1
  ROWS = 48
  SECONDS_PER_ROW = 24*60*60/ROWS
  SECONDS_PER_DAY = 60*60*24
  attr_reader :hours, :from, :to

  def initialize(date)
    case date
    when String
      from = Time.parse(date)
    when Time
      from = date
    else
      from = Time.now
    end
    @from , @to = Calendar.week(from)
    @hours = 0...ROWS
    @table = []
    for i in @hours
      @table[i] =  [ "","","","","","","" ]
    end
  end
  
  def self.week(t)
    t0 = t.to_date
    t0 = t0 - ( t0.wday - FIRST_DAY)
    t0 = t0.to_time
    t1 = t0 + 7 * SECONDS_PER_DAY
    return t0 , t1
  end
  
  def days()
    (0...7).map { |i | @from+i*SECONDS_PER_DAY }
  end
  
  def add(from,to,entry)
    delta = (from-@from).to_i
    column = delta/SECONDS_PER_DAY
    row_from =  (delta % SECONDS_PER_DAY)/ SECONDS_PER_ROW
    row_to   =  row_from + ((to -from) / SECONDS_PER_ROW).to_i
    row = row_from
    event = nil
    for i in row_from...row_to
      if row == ROWS
        row = 0
        column +=1
        event = nil
        break if column >= 7
      end
      if column >= 0 
        unless event
          len = row_to-i
          len = ROWS - row if len + row > ROWS
          event = Event.new(len,entry)
          @table[row][column] = event
        else  
          @table[row][column] = nil
        end
      end
      row += 1
    end
  end
  
  def get(day,hour)
    column = ((day-@from)/SECONDS_PER_DAY).to_i
    row = hour
    @table[row][column]
  end
  
  def to_s
    @table.map { | row | "| " + row.map { | e | e.to_s }.join(" | ") + " |"}.join("\n")
  end
end
