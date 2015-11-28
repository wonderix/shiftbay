# ruby encoding: utf-8
require 'csv'

def time_range(value)
  return [ nil , nil] if value.nil? || value.empty? 
  from, to = value.strip.split(/[\s\-]+/).map{ | t | (Time.parse("2000-01-01T"+t) - Time.local(2000,1,1,0,0,0)).to_i }
  to += 24*60*60 if from > to
  [ from, to ]
end

org = Organization.create(name: "Sonnenhof")

shifts = []
CSV.read(File.join(File.dirname(__FILE__),"shift.csv"),col_sep: ";", encoding: "utf-8").each do | row |
  from1 , to1 = time_range(row[1])
  from2 , to2 = time_range(row[2])
  shifts << Shift.create(:organization => org, :description => row[4],    :abbrev => row[0], :description => row[4], :working_hours => row[3].sub(",",".").to_f, :from1 => from1,  :to1 => to1, :from2 => from2,  :to2 => to2)
end

ex = Qualification.create :name => "Examiniert"
helper = Qualification.create :name => "Helfer"

CSV.read(File.join(File.dirname(__FILE__),"users.csv"),col_sep: ";", encoding: "utf-8").each do | row |
  firstname, lastname = row[0].strip.split(/\s+/)
  lastname = lastname.join(" ") if lastname.is_a?(Array)
  user = User.create :firstname => firstname, :lastname => lastname, :email => "#{firstname}.#{lastname}@sonnenhof.de", :job_title => row[2], :qualification => ( row[2] =~ /ex/ ? ex : helper), password_hash: BCrypt::Password.create("initial")
  employment = org.employments.create(user: user, role: ( user.lastname == "Kramer" ? Employment::MANAGER : Employment::EMPLOYEE ), :level => row[1].to_f/100)
  row[3..-1].each do | i |
    next unless i 
    i.strip!
    next if i.empty?
    team = Team.where(:name => i , organization: org).first_or_create
    TeamMember.create team: team, employment: employment, role: ( user.lastname == "Kramer" ? ( TeamMember::OWNER | TeamMember::PLANNER ):  TeamMember::MEMBER )
  end
      
end

