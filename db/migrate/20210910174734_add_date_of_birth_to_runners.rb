class AddDateOfBirthToRunners < ActiveRecord::Migration[6.1]
  def change
    add_column :runners, :birthdate, :date
  end
end
