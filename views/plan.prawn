
@plans.each do | plan_entry |
  plan = plan_entry.plan
  team = plan.team
  pdf.text plan.team.name

  data = []
  r = []
  r << ""
  plan.each_header do |t|
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
        r << Prawn::Table::Cell.make(pdf, entry.abbrev)
      else
        r << Prawn::Table::Cell.make(pdf, "")
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
  pdf.table(data, :header => true, :font_size => 7, :border_width => 0.1 , 
     :cell_style => { }, 
     :border_color => "AAAAAA", 
     :padding => 2,
     :row_colors => ["FFFFFF", "E0E0E0",  "F0F0F0"]) do
      cells.style(:width => 24, :height => 24)
      cells.style do |c|
        c.background_color = ((c.row + c.column) % 2).zero? ? '000000' : 'ffffff'
      end
  end
  pdf.start_new_page
end