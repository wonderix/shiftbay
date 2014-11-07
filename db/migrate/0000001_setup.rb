
class Setup < ActiveRecord::Migration
  def change
  
    create_table :employees do |t|
      t.string  :name
      t.string  :email
      t.string  :phone
      t.string  :password
      t.string  :mobile
      t.integer :role
      t.integer :notificationType
      t.decimal :working_hours
      t.string  :job_title
      t.belongs_to :area
      t.belongs_to :qualification
   end
    
    create_table :areas_employees do |t|
      t.belongs_to :employee
      t.belongs_to :area
    end
    
    create_table :leaves do |t|
      t.timestamp :from
      t.timestamp :to
      t.integer :type
      t.integer  :state
      t.belongs_to :employee
    end

    create_table :areas do |t|
      t.string :name
    end

    create_table :qualifications do |t|
      t.string :name
    end

    create_table :offers do |t|
      t.decimal :amount
      t.integer :state
      t.belongs_to :staffing
      t.belongs_to :employee
   end

    create_table :shifts do |t|
      t.timestamp :from
      t.timestamp :to
      t.decimal :working_hours
      t.belongs_to :area
    end

   create_table :staffings do |t|
      t.timestamp :from
      t.timestamp :to
      t.decimal :max_amount
      t.integer :employee_count
      t.belongs_to :qualification
      t.belongs_to :shift
    end

    reversible do |dir|
      dir.up do
        ex = Qualification.create :name => "Examiniert"
        for i in 1..4
          Area.create :name => "#{i}. OG"
        end
        %w(Ulrich Monika).each do | name |
          e = ex.employees.create :name => name
          Area.all.each do | area |
            e.areas << area
          end
        end 
        for day in 1..30
          for i in 0...3
            start = Time.local(2014,11,day,i*5+6,0,0)
            Area.all.each do | area |
              shift = ex.shifts.create :from => start, :to => (start+5*60*60), :working_hours => 5.0, :max_amount => 10, :area => area, :employee_count => 2
            end
          end
        end
      end
    end
  end
  
end
