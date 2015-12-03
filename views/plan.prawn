
for i in 0...@plans.length
  pdf.start_new_page if i > 0
  plan = @plans[i].plan
  team = plan.team
  pdf.text plan.team.name

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
  pdf.table(data, :header => true, 
    :cell_style => { 
      :overflow => :shrink_to_fit, 
      :size => 8,
      :border_width => 1, 
      :border_color => "808080",  
      :padding => [2, 2, 2, 2] 
    }) do
      cells.style do |c|
        we = weekend.include?(c.column)
        c.background_color = "%06x" % (0xffffff - (c.row % 3 == 1 ? 0x202020 : 0 ) - ( we ? 0x202020 : 0 ))
      end
  end
end