require 'spec_helper'

describe("Collection create", :type => :request, :integration => true) do

  before(:all) do
    @notice = "Your changes have been saved."
    @edit_path_regex = Regexp.new('/collections/(druid:\w{11})/edit')
    # Need to mint an actual druid in order to pass validation.
    @prev_mint_ids = Dor::Config.configure.suri.mint_ids
    Dor::Config.configure.suri.mint_ids = true
  end

  after(:all) do
    # Restore mint_ids setting.
    Dor::Config.configure.suri.mint_ids = @prev_mint_ids
  end

  it "should be able to create a new Collection and an new APO" do
    ni = hash2struct(
      :title    => 'title_foo',
      :abstract => 'abstract_foo',
      :contact  => 'ozzy@hell.com',
    )
    # Login, go to new Collection page, and store the druid of the new Collection.
    login_as_archivist1
    visit new_hydrus_collection_path()
    current_path.should =~ @edit_path_regex
    druid = @edit_path_regex.match(current_path)[1]
    # Fill in form and save.
    fill_in "hydrus_collection_title",    :with => ni.title
    fill_in "hydrus_collection_abstract", :with => ni.abstract
    fill_in "hydrus_collection_contact",  :with => ni.contact
    click_button "Save"
    page.should have_content(@notice)
    # Get Collection from fedora and confirm that our edits were persisted.
    coll = Hydrus::Collection.find(druid)
    coll.title.should    == ni.title
    coll.abstract.should == ni.abstract
    coll.contact.should  == ni.contact
    coll.should be_instance_of Hydrus::Collection
    # Get the APO of the Collection.
    apo = coll.apo
    apo.should be_instance_of Hydrus::AdminPolicyObject
    # Delete objects.
    coll.delete
    apo.delete
  end

end