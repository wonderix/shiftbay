
class Setup < ActiveRecord::Migration

  def change
  
    create_table :users do |t|
      t.string  :firstname
      t.string  :lastname
      t.string  :email
      t.string  :phone
      t.string  :password_hash
      t.string  :mobile
      t.string  :job_title
      t.belongs_to :qualification
      t.binary    :picture
    end
    
    create_table :calendars do |t|
      t.string  :token, index: true
      t.belongs_to :user
    end
    
    create_table :employments do |t|
      t.belongs_to :user, index: true
      t.belongs_to :organization, index: true
      t.integer    :role
      t.decimal    :level
   end
    
    create_table :organizations do |t|
      t.string     :name
    end

    create_table :teams do |t|
      t.string :name
      t.belongs_to :organization
    end

    create_table :team_members do |t|
      t.belongs_to :employment, index: true
      t.belongs_to :team, index: true
      t.integer    :role
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
      t.string  :description
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

  end
end
