
require 'time'

class Gnatt
  COLUMNS = 48
  

  def initialize(range)
    @range = range
    @hours = 0...COLUMNS
    @table = []
    @start_col = COLUMNS/2
    @end_col = COLUMNS/2+1
  end
  
  def Gnatt.range(date)
    case date
    when String
      date = Time.parse(date)
    when Time
    else
      date = Time.now
    end
    t0 = Time.local(date.year,date.month,date.day,0,0,0)
    t0...(t0 + 24*3600)
  end
  
  def date()
    @range.first.to_date
  end
  
  def add(from,to,entry)
    start_col = ((from - @range.first )/1800).to_i
    end_col = ((to - @range.first +  1799)/1800).to_i
    return if ( start_col >= COLUMNS)
    return if ( end_col <= 0)
    end_col = COLUMNS if ( end_col > COLUMNS) 
    start_col = 0 if (start_col < 0 )
    for row in 0...@table.length
      found = true
      for i in start_col...end_col
        if @table[row][i]
          found = false
          break
        end
      end
      if found
        return add_inner(row,start_col,end_col,entry)
      end
    end
    return add_inner(@table.length,start_col,end_col,entry)
  end
  
  def each_header(&block)
    for col in @start_col...@end_col
      block.call(@range.first+col*1800,2) if col %2 == 0
    end
  end
  
  def add_inner(row,start_col,end_col,entry)
    @start_col  = start_col if start_col < @start_col
    @end_col  = end_col if end_col > @end_col
    @table[row] ||= []
    for i in start_col...end_col
      @table[row][i] = entry
    end
  end
  
  def each_row(&block)
    for row in 0...@table.length
      block.call(row)
    end
  end
  
  def each_col(row,&block)
    start = @start_col
    old = @table[row][@start_col]
    for col in @start_col...@end_col
      event = @table[row][col]
      if event != old
        block.call(start,col-start,old) 
        start = col
        old = event
      end
    end
    block.call(start,@end_col-start,old) 
  end
  
  def to_s
    @table.map { | row | "| " + row.map { | e | e.to_s }.join(" | ") + " |"}.join("\n")
  end
end
