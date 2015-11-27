
class Setup < ActiveRecord::Migration

  def change
  
    create_table :users do |t|
      t.string  :firstname
      t.string  :lastname
      t.string  :email
      t.string  :phone
      t.string  :password
      t.string  :mobile
      t.decimal :level_of_employment
      t.string  :job_title
      t.belongs_to :qualification
      t.belongs_to :organization
      t.binary    :picture
      t.date    :employed_since
      t.date    :employed_until
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
