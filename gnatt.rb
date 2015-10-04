
require 'time'

class Gnatt
  COLUMNS = 48
  

  def initialize(date)
    case date
    when String
      @from = Time.parse(date)
    when Time
      @from = date
    else
      @from = Time.now
    end
    @from = Time.local(@from.year,@from.month,@from.day,0,0,0)
    @hours = 0...COLUMNS
    @table = []
    @start_col = COLUMNS/2
    @end_col = COLUMNS/2+1
  end
  
  def date()
    @from.to_date
  end
  
  def add(from,to,entry)
    start_col = ((from - @from )/1800).to_i
    end_col = ((to - @from +  1799)/1800).to_i
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
      block.call(@from+col*1800,2) if col %2 == 0
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
