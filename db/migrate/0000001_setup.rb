
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
      t.belongs_to :organization
      t.belongs_to :qualification
   end
    
 
    create_table :organizations do |t|
      t.string :name
    end

    create_table :qualifications do |t|
      t.string :name
    end

   create_table :shifts do |t|
      t.integer :from1
      t.integer :to1
      t.integer :from2
      t.integer :to2
      t.string  :name
      t.string  :abbrev
      t.decimal :working_hours
    end
    
    add_index :shifts, :abbrev

    create_table :staffings do |t|
      t.date       :date
      t.belongs_to :user
      t.belongs_to :shift
      t.belongs_to :organization
    end


    reversible do |dir|
      dir.up do
        ex = Qualification.create :name => "Examiniert"
        orgs = [ "1. OG" , "EG" , "2. OG" , "West" , "3. OG" ].map{ | i |  Organization.create :name => i }
        users = %w(Ulrich Monika Julian Daniel Thorsten).map{ | name | User.create :name => name, :email => "#{name}@web.de", :qualification => ex, :organization => orgs[rand(5)] }
        t0 = Time.local(2000,1,1.0,0,0)
        shifts = []
        shifts << Shift.create(:name => "Früh",    :abbrev => "F", :working_hours => 6.25, :from1 => offset("6:15"),  :to1 => offset("13:30"))
        shifts << Shift.create(:name => "Spät",    :abbrev => "S", :working_hours => 6.25, :from1 => offset("13:00"), :to1 => offset("20:00"))
        shifts << Shift.create(:name => "Geteilt", :abbrev => "G", :working_hours => 6.25, :from1 => offset("6:15"),  :to1 => offset("11:00"), :from2 => offset("16:00") , :to2 => offset("20:00"))
        shifts << Shift.create(:name => "Nacht",   :abbrev => "N", :working_hours => 12,   :from1 => offset("20:00"), :to1 => offset("6:30")+24*60*60)
        for day in 1..30
          date = Date.new(2015,10,day)
          users.each do | u |
            shift = shifts[rand(10)]
            next unless shift
            Staffing.create(:date => date, :user=> u , :shift => shift, :organization => orgs[rand(5)])
          end
        end
      end
    end
  end
end
