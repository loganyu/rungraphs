class Result < ApplicationRecord
	attr_accessor :overall_rank, :gender_rank

  belongs_to :runner, inverse_of: :results
  belongs_to :race, inverse_of: :results

  def full_name
    self.first_name + ' ' + self.last_name
  end

end
