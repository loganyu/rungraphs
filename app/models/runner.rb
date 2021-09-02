require 'elasticsearch/model'

class Runner < ApplicationRecord
	include Elasticsearch::Model
 	# include Elasticsearch::Model::Callbacks
 	extend FriendlyId
  friendly_id :generate_custom_slug, :use => :slugged

  has_many :results, inverse_of: :runner
	has_many :races, through: :results
	
  settings index: {
		number_of_shards: 1
		},
		analysis: {
			filter: {
			    autocomplete_filter: {
			      type: "edge_ngram",
			      min_gram: 2,
			      max_gram: 4
		    	}
			},
			analyzer: {
		    autocomplete: {
		      tokenizer: "lowercase",
		      filter: ["lowercase", "autocomplete_filter"],
		      type: "custom"
		    }
		  }
	  }	do
	  mappings dynamic: 'true' do
	    indexes :name, analyzer: 'autocomplete'
	  end

	end

	def self.search(query)
	  __elasticsearch__.search(
	    {
	      query: {
	        multi_match: {
	          query: query,
	          fields: ["full_name"]
	        }
	      },
	      fields: ['full_name', 'team', 'id', 'slug']
	    }
	  )
	end

	def generate_custom_slug
    ["#{self.first_name} #{self.last_name}", "#{self.first_name} #{self.last_name} #{self.city}"]
  end

  def full_name
  	[first_name, last_name].join(' ')
	end
end
