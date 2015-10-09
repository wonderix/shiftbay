
class Setup < ActiveRecord::Migration

  def offset(t)
    return Time.parse("2000-01-01T"+t) - Time.local(2000,1,1,0,0,0)
  end
  def change
  
    create_table :users do |t|
      t.string  :name
      t.string  :email
      t.string  :phone
      t.string  :password
      t.string  :mobile
      t.integer :role
      t.integer :notification_type
      t.decimal :working_hours
      t.string  :job_title
      t.belongs_to :qualification
      t.binary    :picture
   end
    
    
    create_table :organizations do |t|
      t.string     :name
    end

    create_table :groups do |t|
      t.string     :name
      t.integer    :role
      t.belongs_to :organization
    end

   create_table :group_members do |t|
      t.belongs_to :user, index: true
      t.belongs_to :group, index: true
    end

    create_table :teams do |t|
      t.string :name
      t.belongs_to :organization
    end

    create_table :team_members do |t|
      t.belongs_to :user, index: true
      t.belongs_to :team, index: true
    end
 
    create_table :qualifications do |t|
      t.string :name
      t.belongs_to :organization
    end

   create_table :shifts do |t|
      t.integer :from1
      t.integer :to1
      t.integer :from2
      t.integer :to2
      t.string  :name
      t.string  :abbrev
      t.decimal :working_hours
      t.belongs_to :organization
    end
    
    add_index :shifts, :abbrev

    create_table :staffings do |t|
      t.date       :date
      t.belongs_to :user
      t.belongs_to :shift
      t.belongs_to :team
    end


    reversible do |dir|
      dir.up do
      
        org = Organization.create(name: "Sonnenhof")
        ex = Qualification.create :name => "Examiniert"
        teams = [ "1. OG" , "EG" , "2. OG" , "West" , "3. OG" ].map{ | i |  Team.create :name => i , organization: org }
        users = %w(Ulrich Monika Julian Daniel Thorsten).map{ | name | User.create :name => name, :email => "#{name}@web.de", :qualification => ex }
        group = Group.create(organization: org, name: "Owners" , role: Group::OWNER )
        GroupMember.create(group: group, user: users[0])
        group = Group.create(organization: org, name: "Members" , role: Group::MEMBER )
        teams.each do | team |
          TeamMember.create team: team, user: users[0] 
        end
        users[1...-1].each do | user |
          TeamMember.create team: teams[0], user: user
        end          

        shifts = []
        shifts << Shift.create(:organization => org, :name => "Früh",    :abbrev => "F", :working_hours => 6.25, :from1 => offset("6:15"),  :to1 => offset("13:30"))
        shifts << Shift.create(:organization => org, :name => "Spät",    :abbrev => "S", :working_hours => 6.25, :from1 => offset("13:00"), :to1 => offset("20:00"))
        shifts << Shift.create(:organization => org, :name => "Geteilt", :abbrev => "G", :working_hours => 6.25, :from1 => offset("6:15"),  :to1 => offset("11:00"), :from2 => offset("16:00") , :to2 => offset("20:00"))
        shifts << Shift.create(:organization => org, :name => "Nacht",   :abbrev => "N", :working_hours => 12,   :from1 => offset("20:00"), :to1 => offset("6:30")+24*60*60)
        for day in 1..30
          date = Date.new(2015,10,day)
          users.each do | u |
            shift = shifts[rand(10)]
            next unless shift
            Staffing.create(:date => date, :user=> u , :shift => shift, :team => teams[0])
          end
        end
      end
    end
  end
end
