class ProjectedResult < ApplicationRecord
  belongs_to :runner, optional: true
  belongs_to :projected_race, inverse_of: :projected_results
end
