namespace :hydrus do
  desc 'associate DOR item with Hydrus'
  # associates a non-hydrus DOR item with the Hydrus app by adding datastreams and indexing into Hydrus solr
  # need to pass in druid of object to associated, collection druid of Hydrus collection to associate with, and type of hydrus object (e.g. dataset)
  # run with RAILS_ENV=production rake hydrus:index_object druid=druid:oo000oo0001 collection=druid:oo00oo002 type=dataset
  task index_object: :environment do |t, args|
    druid = ENV['druid'] # druid to index (full druid, including druid: prefix)
    collection = ENV['collection'] # druid of collection to associate with  (full druid, including druid: prefix)
    item_type = ENV['type'] # type of hydrus item

    item=Hydrus::Item.find(druid) # get druid

    coll = Hydrus::Collection.find(collection)

    # Add the Item to the Collection.
    item.collections << coll

    # change item type in RELS-EXT to be a hydrus item
    item.datastreams['RELS-EXT'].content.gsub!('<fedora-model:hasModel rdf:resource="info:fedora/afmodel:Dor_Item"></fedora-model:hasModel>','<fedora-model:hasModel rdf:resource="info:fedora/afmodel:Hydrus_Item"/>')
    item.remove_relationship :has_model, 'info:fedora/afmodel:Dor_Item'
    item.assert_content_model

    # ruby black magic: redefine should_validate and another method so we can save this hydrus item without going through all of the UI validations
    item.define_singleton_method :should_validate, lambda {false}
    item.define_singleton_method :check_version_if_license_changed, lambda {return}

    # create hydrusProperties datastream and set values
    item.item_type=item_type
    item.accepted_terms_of_deposit='true'
    item.reviewed_release_settings='true'
    item.hydrusProperties.requires_human_approval='false'
    item.object_status='published'
    item.hydrusProperties.last_modify_time=Time.now.to_s
    item.hydrusProperties.submit_for_approval_time=Time.now.to_s
    item.hydrusProperties.initial_publish_time=Time.now.to_s
    item.hydrusProperties.initial_submitted_for_publish_time=Time.now.to_s
    item.hydrusProperties.submitted_for_publish_time=Time.now.to_s

    # save item
    item.save

    # index into solr
    solr=Dor::SearchService.solr
    solr_doc = item.to_solr
    solr.add(solr_doc, add_attributes: {commitWithin: 5000})
  end

  desc 'Index all DOR defined workflow objects into Hydrus solr instance'
  task index_all_workflows: :environment do
    # get all workflow objects using risearch (sparql on fedora) since we don't have a direct connection to argo solr
    model_type = "<#{Dor::WorkflowObject.to_class_uri}>"
    solr = Dor::SearchService.solr
    pids = Dor::SearchService.risearch 'select $object from <#ri> where $object ' "<fedora-model:hasModel> #{model_type}", { limit: nil }
    pids.each { |pid| solr.add(Dor.find(pid).to_solr, add_attributes: {commitWithin: 5000}) }     # index into hydrus solr
  end

  desc 'Cleanup file upload temp files'
  task cleanup_tmp: :environment do
    CarrierWave.clean_cached_files!
  end
end


desc 'rails server with suppressed output'
task server: :environment do
  # Note: to get this to work nicely, we also set the app to generate
  # unbuffered output: see config/application.rb.
  system 'rake jetty:start' unless `rake jetty:status` =~ /^Running:/
  exclusions = [
    'WARN  Could not determine content-length of response',
    '^Loaded datastream druid:',
    '^Loaded datastream list',
    '^Solr response: '
  ]
  regex = exclusions.join('|')
  cmd = [
    'rails server 2>&1',
    %Q<ruby -ne 'BEGIN { STDOUT.sync = true }; print $_ unless $_ =~ /#{regex}/'>
  ].join(' | ')
  system(cmd)
end
