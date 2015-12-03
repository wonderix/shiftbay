
for i in 0...@plans.length
  pdf.start_new_page if i > 0
  plan = @plans[i].plan
  team = plan.team
  pdf.text plan.team.name
  pdf.text @range.first.to_s, size: 10

  weekend = []
  data = []
  r = []
  r << ""
  plan.each_header do |t|
    weekend << r.length if t.sunday? || t.saturday?
    r << "#{t.strftime("%d")}"
  end 
  r << "Ist"
  r << "Soll"
  data << r
  
  plan.each_row do |row|
    r = []
    if plan.team != row.team
      r << "#{row.user.name} (#{row.team.name})"
    else
      r << "#{row.user.name}"
    end
    row.each do |entry,t|
      case entry
      when Shift
        r << entry.abbrev
      else
        r << ""
      end
    end
    r << ("%5.1f" % row.working_hours)
    r << ("%5.1f" % (plan.working_hours*row.level_of_employment))
    data << r
    r = []
    r << row.user.job_title
    row.each do |entry,t|
      r << ""
    end
    r << ""
    r << ""
    data << r
    r = []
    r << "BV #{(row.level_of_employment*100).to_i}%"
    row.each do |entry,t|
      r << ""
    end
    r << ""
    r << ""
    data << r
  end
  options = {
    :header => true, 
    :cell_style => { 
      :overflow => :shrink_to_fit, 
      :size => 8,
      :border_width => 1, 
      :border_color => "808080",  
      :padding => [2, 2, 2, 2] 
    }
    
  }
  pdf.table(data,options)  do
    cells.style do |c|
      we = weekend.include?(c.column)
      c.background_color = "%06x" % (0xffffff - (c.row % 3 == 1 ? 0x202020 : 0 ) - ( we ? 0x202020 : 0 ))
    end
  end
  pdf.move_down(30)
  pdf.text "Legende", :size => 10

  data = []
  r = []
  cols = 3
  cols.times do 
    r += [ "" , "von" , "bis" , "von", "bis", "Beschreibung"]
  end
  data << r
  r = []
  time = Time.local(2000,1,1,0,0,0)
  shifts = @organization.shifts.order(:abbrev).to_a
  while ! shifts.empty?
    r = []
    shifts.shift(cols).each do | shift |
      r << shift.abbrev
      r << (shift.from1 ? (time + shift.from1).strftime("%H:%M") : "")
      r << (shift.to1 ? (time + shift.to1).strftime("%H:%M") : "")
      r << (shift.from2 ? (time + shift.from2).strftime("%H:%M") : "")
      r << (shift.to2 ? (time + shift.to2).strftime("%H:%M") : "")
      r << shift.description
    end
    data << r
  end
  options[:cell_style][:size] = 6
  pdf.table(data,options)  do
    cells.style do |c|
      c.background_color = "%06x" % ( c.column % 6 == 0 ? 0xdfdfdf : 0xffffff ) 
    end
  end

end