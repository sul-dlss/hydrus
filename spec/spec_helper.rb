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

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require 'capybara/rspec'
require 'tempfile'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|

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

  config.around(:each) do |example|
    ActiveFedora::Base.connection_for_pid(0).transaction do |t|
      example.call
      t.rollback
    end
  end
end

Dor::Config.configure.suri.mint_ids = false

# Create a Nokogiri document from an XML source, with some whitespace configuration.
def noko_doc(x)
  Nokogiri.XML(x) { |conf| conf.default_xml.noblanks }
end

def mock_user
  mock_user =  mock("user")
  mock_user.stub!(:email)
  mock_user.stub!(:sunetid)
  mock_user.stub!(:persisted?).and_return(false)
  mock_user.stub!(:new_record?).and_return(true)
  mock_user.stub!(:is_being_superuser?).and_return(false)
  return mock_user
end

def mock_authed_user
  mock_user =  mock("user")
  mock_user.stub!(:email).and_return("archivist1@example.com")
  mock_user.stub!(:sunetid).and_return("archivist1")
  mock_user.stub!(:persisted?).and_return(true)
  mock_user.stub!(:new_record?).and_return(false)
  mock_user.stub!(:is_being_superuser?).and_return(false)
  return mock_user
end

def login_pw
  'beatcal'
end

def login_as_archivist1
  login_as "archivist1@example.com", login_pw
end

def login_as_archivist2
  login_as "archivist2@example.com", login_pw
end

def login_as_archivist6
  login_as "archivist6@example.com", login_pw
end

def login_as_archivist99
  login_as "archivist99@example.com", login_pw
end

def login_as(email, password)
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
  current_path.should == polymorphic_path(obj)
end

def should_visit_edit_page(obj)
  visit edit_polymorphic_path(obj)
  current_path.should == edit_polymorphic_path(obj)
end

def confirm_rights_metadata_in_apo(obj)
  obj.apo.defaultObjectRights.ng_xml.should be_equivalent_to obj.rightsMetadata.ng_xml # collection rights metadata should be equal to apo default object rights    
end

def confirm_rights(obj,params)
    
  # all should be world discoverable
  obj.rightsMetadata.ng_xml.xpath('//access[@type="discover"]/machine/world').size.should == 1
  obj.embargoMetadata.ng_xml.xpath('//access[@type="discover"]/machine/world').size.should == 1 if obj.embargo == 'future'

  datastream = (obj.embargo == 'future' ? obj.embargoMetadata : obj.rightsMetadata)
  case params[:visibility]
    when "stanford" 
      datastream.ng_xml.xpath('//access[@type="read"]/machine/group').size.should == 1
      datastream.ng_xml.at_xpath('//access[@type="read"]/machine/group').content.should == 'stanford'
      datastream.ng_xml.xpath('//access[@type="read"]/machine/world').size.should == 0
    when "world"
      datastream.ng_xml.xpath('//access[@type="read"]/machine/group').size.should == 0
      datastream.ng_xml.xpath('//access[@type="read"]/machine/world').size.should == 1
  end

  if params[:embargo_date] == ""
    obj.rightsMetadata.ng_xml.xpath('//access[@type="read"]/machine/embargoReleaseDate').size.should == 0 
  else
    obj.rightsMetadata.ng_xml.at_xpath('//access[@type="read"]/machine/embargoReleaseDate').content.should == params[:embargo_date]    
  end
  
  obj.rightsMetadata.ng_xml.at_xpath('//use/machine').content.should == params[:license_code]
  
end

# Some integration tests requires the minting of a valid druid in
# order to pass validations. This method can be used to set the mint_ids
# configuration to true, and then latter restore the previous value.
def config_mint_ids(prev = nil)
  dcc = Dor::Config.configure
  if prev.nil?
    prev = dcc.suri.mint_ids
    dcc.suri.mint_ids = true
  else
    dcc.suri.mint_ids = prev
  end
  return prev
end
