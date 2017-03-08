# for test coverage
ruby_engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"

if ENV['COVERAGE'] == "true" and ruby_engine != "jruby"
  require 'simplecov'
  require 'simplecov-rcov'

  class SimpleCov::Formatter::MergedFormatter
    def format(result)
       SimpleCov::Formatter::HTMLFormatter.new.format(result)
       SimpleCov::Formatter::RcovFormatter.new.format(result)
    end
  end
  SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
  SimpleCov.start do
    # group coverage data
    add_group "Controllers", "app/controllers"
    add_group "Helpers", "app/helpers"
    add_group "Mailers", "app/mailers"
    add_group "Models", "app/models"
    # exclude from coverage
    add_filter "config/"
    add_filter "features/"
    add_filter "spec/"
  end
end

ENV["RAILS_ENV"] ||= 'test'
require 'webmock/rspec'
WebMock.disable_net_connect!(allow: ['127.0.0.1', 'localhost'])
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rspec'
require 'tempfile'
require 'rspec/matchers' # req by equivalent-xml custom matcher `be_equivalent_to`
require 'equivalent-xml'
require 'equivalent-xml/rspec_matchers'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

Warden.test_mode!

RSpec.configure do |config|

  config.include Devise::TestHelpers, :type => :controller
  config.include Warden::Test::Helpers, :type => :controller
  config.after(:each) { Warden.test_reset! }

  config.include Capybara::DSL

  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/test/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Restore prior state of Fedora repository.
  config.around(:each) do |example|
    ActiveFedora::Base.connection_for_pid(0).transaction do |t|
      example.call
      # TODO: simplify if rollback_fixtures() is incorporated into Rubydora.
      if ENV['USE_OLD_ROLLBACK']
        t.rollback
      else
        t.rollback_fixtures(FIXTURE_FOXML)
      end
    end
  end

end

Dor::Config.configure.suri.mint_ids = false

FIXTURE_FOXML = Hydrus.all_fixture_foxml()

# TODO: incorporate this into Rubydora.
# Relative to rollback() it Rubydora v0.5.0, it reduced
# test suite runtime from 32 min down to about 8 min.
# Not sure what the two run_hook() calls do or whether they are needed;
# just copied the approach used in Rubydora's rollback().
class Rubydora::Transaction

    # Roll-back transactions by restoring the repository to its
    # original state, based on fixtures that are passed in as a
    # hash, with PIDs and keys and foxml as values.
    def rollback_fixtures(fixtures)
      solr = RSolr.connect(Blacklight.solr_config)
      # Two sets of PIDs:
      #   - everything that was modified
      #   - fixtures that were modified
      aps = Set.new(all_pids)
      fps = Set.new(fixtures.keys) & aps
      # Rollback.
      # Just swallow any exceptions.
      without_transactions do
        # First, purge everything that was modified.
        aps.each do |p|
          begin
            repository.purge_object(:pid => p)
            solr.delete_by_id p
            #run_hook(:after_rollback, :pid => p, :method => :ingest)
          rescue
          end
        end
        # Then restore the fixtures to their original state.
        fixtures.each do |p, foxml|
          next unless fps.include?(p)
          begin
            repository.ingest(:pid => p, :file => foxml)
            $fixture_solr_cache ||= {}
            $fixture_solr_cache[p] ||= begin
              puts" indexing and caching #{p}"
              ActiveFedora::Base.find(p, :cast => true).to_solr
            end
            solr.add $fixture_solr_cache[p]
            #run_hook(:after_rollback, :pid => p, :method => :purge_object)
          rescue
          end
        end
      end
      # Wrap up.
      solr.commit
      repository.transactions_log.clear
      return true
    end

    # Returns the pids of all objects modified in any way during the transaction.
    def all_pids
      repository.transactions_log.map { |entry| entry.last[:pid] }.uniq
    end

end

# Create a Nokogiri document from an XML source, with some whitespace configuration.
def noko_doc(x)
  Nokogiri.XML(x) { |conf| conf.default_xml.noblanks }
end

def mock_user
  User.find_or_create_by_email("some-user@example.com") do |u|
    u.password = "test12345"
    u.password_confirmation = u.password
    u.save
  end
end

def mock_authed_user(u = 'archivist1')
  User.find_by_email("#{u}@example.com")
end

def login_pw
  'beatcal'
end

def login_as(email, password = nil)
  password ||= login_pw
  email += '@example.com' unless email.include?('@')
  logout
  visit new_user_session_path
  fill_in "Email", :with => email
  fill_in "Password", :with => password
  click_button "Sign in"
end

def logout
  visit destroy_user_session_path
end

# Takes a hash and returns a corresponding Struct.
def hash2struct(h)
  return Struct.new(*h.keys).new(*h.values)
end

def should_visit_view_page(obj)
  visit polymorphic_path(obj)
  expect(current_path).to eq(polymorphic_path(obj))
end

def should_visit_edit_page(obj)
  visit edit_polymorphic_path(obj)
  expect(current_path).to eq(edit_polymorphic_path(obj))
end

# Takes a collection.
# Visits url to create new item in that collection.
# Extracts the new item's druid from the path and returns it.
def should_visit_new_item_page(coll)
  rgx = Regexp.new('/items/(druid:\w{11})/edit')
  visit new_hydrus_item_path(:collection => coll)
  expect(current_path).to match(rgx)
  druid = rgx.match(current_path)[1]
  return druid
end

def confirm_rights_metadata_in_apo(obj)
  expect(obj.apo.defaultObjectRights.ng_xml).to be_equivalent_to(obj.rightsMetadata.ng_xml) # collection rights metadata should be equal to apo default object rights
end

def check_emb_vis_lic(obj, opts)
  # This method takes an Item or Collection and checks various values
  # in its embargoMetadata and rightsMetadata. The expectations are passed in
  # as a hash of options.
  #
  # An object's embargo status affects both the embargoMetadata
  # and rightsMetadata, as summarized here:
  #
  # is_embargoed = true
  #   embargoMetadata
  #     releaseAccess read node should = world|stanford
  #     status = embargoed
  #     releaseDate = DATETIME
  #   rightsMetadata
  #     read access = NONE
  #     embargoReleaseDate = DATETIME
  #
  # is_embargoed = false
  #   embargoMetadata
  #     datastream should be empty
  #   rightsMetadata
  #     read access should = world|stanford
  #     should be no embargoReleaseDate node

  # Some convenience variables.
  di     = '//access[@type="discover"]/machine'
  rd     = '//access[@type="read"]/machine'
  rm     = obj.rightsMetadata
  em     = obj.embargoMetadata
  is_emb = (obj.class == Hydrus::Item and obj.is_embargoed)

  # Consistency between is_embargoed() and testing expectations.
  expect(opts[:embargo_date].blank?).to eq(not(is_emb))

  # All objects should be world discoverable.
  expect(obj.rightsMetadata.ng_xml.xpath("#{di}/world").size).to eq(1)
  expect(obj.embargoMetadata.ng_xml.xpath("#{di}/world").size).to eq(1) if is_emb

  # Some checks based on embargo status.
  if is_emb
    # embargoMetadata
    expect(em.ng_xml.at_xpath('//status').content).to eq('embargoed')
    expect(em.ng_xml.at_xpath('//releaseDate').content).to eq(opts[:embargo_date])
    # rightsMetadata
    expect(rm.has_world_read_node).to eq(false)
    expect(rm.group_read_nodes.size).to eq(0)
    expect(rm.ng_xml.at_xpath("#{rd}/embargoReleaseDate").content).to eq(opts[:embargo_date])
    expect(rm.ng_xml.xpath("#{rd}/none").size).to eq(1)
  else
    # embargoMetadata: should be empty
    expect(em.ng_xml.content.strip).to be_empty
    # rightsMetadata: should not have an embargoReleaseDate.
    expect(rm.ng_xml.xpath("#{rd}/embargoReleaseDate").size).to eq(0)
    expect(rm.ng_xml.xpath("#{rd}/none").size).to eq(0)
  end

  # Check visibility: (world|stanford) stored in either embargoMetadata or rightsMetadata.
  datastream = (is_emb ? em : rm)
  g = datastream.ng_xml.xpath("#{rd}/group")
  w = datastream.ng_xml.xpath("#{rd}/world")
  if opts[:visibility] == "stanford"
    expect(g.size).to eq(1)
    expect(g.first.content).to eq('stanford')
    expect(w.size).to eq(0)
  else # "world"
    expect(g.size).to eq(0)
    expect(w.size).to eq(1)
  end

  # Check the license in rightsMetadata.
  u = obj.rightsMetadata.ng_xml.at_xpath('//use/machine')
  expect(u.content).to eq(opts[:license_code].sub(/\Acc-/, ''))
end

# Some integration tests requires the minting of a valid druid in
# order to pass validations. This method can be used to set the mint_ids
# configuration to true, and then latter restore the previous value.
def config_mint_ids(prev = nil)
  suri = Dor::Config.configure.suri
  if prev.nil?
    prev = suri.mint_ids
    suri.mint_ids = true
  else
    suri.mint_ids = prev
  end
  return prev
end

# Creates a new collection through the UI.
# User can pass in options to control how the form is filled out.
# Returns the new collection.
def create_new_collection(opts = {})
  # Setup options.
  default_opts = {
    :user                    => 'archivist1',
    :title                   => 'title_foo',
    :abstract                => 'abstract_foo',
    :contact                 => 'foo@bar.com',
    :requires_human_approval => 'yes',
    :viewers                 => '',
  }
  opts = hash2struct(default_opts.merge opts)
  # Login and create new collection.
  login_as(opts.user)
  visit(new_hydrus_collection_path)
  # Extract the druid from the URL.
  r = Regexp.new('/collections/(druid:\w{11})/edit')
  m = r.match(current_path)
  expect(m).not_to be_empty
  druid = m[1]
  # Fill in required fields.
  hc    = 'hydrus_collection'
  rmdiv = find('div#role-management')
  dk    = 'hydrus_collection_apo_person_roles'
  fill_in "#{hc}_title",    :with => opts.title
  fill_in "#{hc}_abstract", :with => opts.abstract
  fill_in "#{hc}_contact",  :with => opts.contact
  fill_in "#{hc}_apo_person_roles[hydrus-collection-viewer]", :with => opts.viewers
  choose  "#{hc}_requires_human_approval_" + opts.requires_human_approval
  # Save.
  click_button "save_nojs"
  expect(current_path).to eq("/collections/#{druid}")
  expect(find('div.alert')).to have_content("Your changes have been saved")
  # Get the collection from Fedora and return it.
  return Hydrus::Collection.find(druid)
end

# Creates a new item through the UI.
# User can pass in options to control how the form is filled out.
# Returns the new item.
def create_new_item(opts = {})
  # Setup options.
  default_opts = {
    :collection_pid          => 'druid:oo000oo0003',
    :user                    => mock_authed_user,
    :title                   => 'title_foo',
    :abstract                => 'abstract_foo',
    :contributor             => 'foo_contributor',
    :contact                 => 'foo@bar.com',
    :keywords                => 'topicA,topicB',
    :requires_human_approval => 'yes',
    :date_created            => '2011',
  }
  opts = hash2struct(default_opts.merge opts)
  # Set the Collection's require_human_approval value.
  hc = Hydrus::Collection.find(opts.collection_pid)
  hc.requires_human_approval = opts.requires_human_approval
  hc.save
  # Login and create new item.
  login_as(opts.user.to_s)
  visit new_hydrus_item_path(:collection => hc.pid)
  # Extract the druid from the URL.
  r = Regexp.new('/items/(druid:\w{11})/edit')
  m = r.match(current_path)
  expect(m).not_to be_empty
  druid = m[1]
  # Fill in the required fields.
  click_button('Add Contributor')
  fill_in "hydrus_item_contributors_0_name", :with => opts.contributor
  fill_in "Title of item",        :with => opts.title
  fill_in "hydrus_item_abstract", :with => opts.abstract
  fill_in "hydrus_item_contact",  :with => opts.contact
  fill_in "hydrus_item_keywords", :with => opts.keywords
  fill_in "hydrus_item_dates_date_created", :with => opts.date_created
  choose "hydrus_item_dates_date_type_single"
  check "release_settings"
  # Add a file.
  f      = Hydrus::ObjectFile.new
  f.pid  = druid
  f.file = Tempfile.new('mock_HydrusObjectFile_')
  f.save
  # Save.
  click_button "save_nojs"
  expect(current_path).to eq("/items/#{druid}")
  expect(find('div.alert')).to have_content("Your changes have been saved")
  # Agree to terms of deposit (hard to do via the UI).
  hi = Hydrus::Item.find(druid)
  hi.accept_terms_of_deposit(opts.user)
  hi.save
  # Get the item from Fedora and return it.
  should_visit_view_page(hi)
  return Hydrus::Item.find(druid)
end

# Takes the file_url of an Item's uploaded file.
# Helper method to restore a file to the uploads directory
# after it was deleted in a integration test.
def restore_upload_file(file_url)
  parts = file_url.split /\//
  parts[0] = 'public'
  dst = File.join(*parts)
  src = File.join('spec/fixtures/files', parts[-3], parts[-1])
  FileUtils.cp(src, dst)
end
