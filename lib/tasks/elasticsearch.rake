namespace :elasticsearch do
  task :reindex => :environment do
    # Delete the previous races index in Elasticsearch
    Race.__elasticsearch__.client.indices.delete index: Race.index_name rescue nil

    # Create the new index with the new mapping
    Race.__elasticsearch__.client.indices.create \
      index: Race.index_name,
      body: { settings: Race.settings.to_hash, mappings: Race.mappings.to_hash }

    # Index all races records from the DB to Elasticsearch
    Race.import


    # Delete the previous runners index in Elasticsearch
    Runner.__elasticsearch__.client.indices.delete index: Runner.index_name rescue nil

    # Create the new index with the new mapping
    Runner.__elasticsearch__.client.indices.create \
      index: Runner.index_name,
      body: { settings: Runner.settings.to_hash, mappings: Runner.mappings.to_hash }

    # Index all races records from the DB to Elasticsearch
    Runner.import
  end
end
