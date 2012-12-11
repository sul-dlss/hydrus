require 'spec_helper'

describe("Item edit", :type => :request, :integration => true) do
  fixtures :users

  before :each do
    @druid = 'druid:oo000oo0001'
    @hi    = Hydrus::Item.find @druid
    @notice = "Your changes have been saved."
    @buttons = {
      :add                 => 'Add',
      :save                => 'Save',
      :add_person          => 'Add Person',
      :submit_for_approval => 'Submit for Approval',
      :resubmit            => 'Resubmit for Approval',
      :disapprove          => 'Return Item',
      :approve             => 'Approve Item',
      :publish_directly    => 'Publish',
    }
  end

  it "If not logged in, should be redirected to the login page, then back to our intended page after logging in" do
    logout
    visit edit_polymorphic_path(@hi)
    current_path.should == new_signin_path
    fill_in "Email", :with => 'archivist1@example.com'
    fill_in "Password", :with => login_pw
    click_button "Sign in"
    current_path.should == edit_polymorphic_path(@hi)
  end

  it "should be able to edit simple items: abstract, contact, keywords" do
    # Set up the new values for the fields we will edit.
    ni = hash2struct(
      :abstract => 'abcxyz123',
      :contact  => 'ozzy@hell.com',
      :keywords => %w(foo bar fubb),
    )
    comma_join  = '  ,  '
    # Visit edit page.
    login_as('archivist1')
    should_visit_edit_page(@hi)
    # Make sure the object does not have the new content yet.
    @hi.abstract.should_not == ni.abstract
    @hi.contact.should_not  == ni.contact
    @hi.keywords.should_not == ni.keywords
    find_field("Abstract").value.should_not include(ni.abstract)
    find_field("hydrus_item_contact").value.should_not include(ni.contact)
    find_field("Keywords").value.should_not include(ni.keywords[0])
    # Submit some changes.
    fill_in("Abstract", :with => "  #{ni.abstract}  ")
    fill_in("hydrus_item_contact", :with => "  #{ni.contact}  ")
    fill_in("Keywords", :with => "  #{ni.keywords.join(comma_join)}  ")
    click_button "Save"
    # Confirm new location and flash message.
    current_path.should == polymorphic_path(@hi)
    page.should have_content(@notice)
    # Confirm new content in fedora.
    @hi = Hydrus::Item.find @druid
    @hi.abstract.should == ni.abstract
    @hi.contact.should  == ni.contact
    @hi.keywords.should == ni.keywords
  end

  it "People/Role editing" do

    new_name  = "MY EDITIED PERSON"
    orig_name = "Rosenfeld, Michael J."
    field_np  = "hydrus_item_person_0"
    field_rt  = "hydrus_item_person_role_0"
    orig_role = "Principal Investigator"
    new_role  = "Collector"

    login_as('archivist1')
    should_visit_edit_page(@hi)

    find_field(field_np).value.should == orig_name
    page.should have_content(orig_role)

    fill_in(field_np, :with => new_name)
    select(new_role, :from => field_rt)
    click_button "Save"
    page.should have_content(@notice)

    current_path.should == polymorphic_path(@hi)
    visit polymorphic_path(@hi)
    page.should have_content(new_name)
    page.should have_content(new_role)

  end

  it "People/Role adding and deleting" do
    new_field = "hydrus_item_person_5"
    new_delete_button = "remove_name_5"
    person = "Mr. Test Person"

    login_as('archivist1')
    should_visit_edit_page(@hi)

    page.should have_css("input#hydrus_item_person_4")
    page.should_not have_css("##{new_field}")

    click_button "add_person"
    page.should have_css("##{new_field}")
    page.should have_css("##{new_delete_button}")

    fill_in(new_field, :with => person)
    click_button "Save"
    page.should have_content(@notice)

    should_visit_edit_page(@hi)

    page.should have_css("##{new_delete_button}")
    find_field(new_field).value.should == person

    # delete
    click_link new_delete_button

    current_path.should == edit_polymorphic_path(@hi)
    page.should_not have_css("##{new_field}")
    page.should_not have_css("##{new_delete_button}")
  end

  it "Related Content editing with adding protocol if it is missing" do
    orig_link   = @hi.descMetadata.relatedItem.location.url.first
    new_link    = "foo_LINK_bar"
    field_link  = "hydrus_item_related_item_url_0"
    orig_title  = @hi.descMetadata.relatedItem.titleInfo.title.first
    new_title   = "foo_TITLE_bar"
    field_title = "hydrus_item_related_item_title_0"

    login_as('archivist1')
    should_visit_edit_page(@hi)

    find_field(field_link).value.should == orig_link
    find_field(field_title).value.should == orig_title

    fill_in(field_link,  :with => new_link)
    fill_in(field_title, :with => new_title)
    click_button "Save"
    page.should have_content(@notice)

    # Confirm new content in fedora.
    @hi = Hydrus::Item.find(@druid)
    @hi.descMetadata.relatedItem.titleInfo.title.first.should == new_title
    @hi.descMetadata.relatedItem.location.url.first == "http://#{new_link}"
  end

  it "Related Content editing" do
    orig_link   = @hi.descMetadata.relatedItem.location.url.first
    new_link    = "https://foo_LINK_bar"
    field_link  = "hydrus_item_related_item_url_0"
    orig_title  = @hi.descMetadata.relatedItem.titleInfo.title.first
    new_title   = "foo_TITLE_bar"
    field_title = "hydrus_item_related_item_title_0"

    login_as('archivist1')
    should_visit_edit_page(@hi)

    find_field(field_link).value.should == orig_link
    find_field(field_title).value.should == orig_title

    fill_in(field_link,  :with => new_link)
    fill_in(field_title, :with => new_title)
    click_button "Save"
    page.should have_content(@notice)

    # Confirm new content in fedora.
    @hi = Hydrus::Item.find(@druid)
    @hi.descMetadata.relatedItem.titleInfo.title.first.should == new_title
    @hi.descMetadata.relatedItem.location.url.first == new_link
  end


  it "Related Content adding and deleting" do
    i             = @hi.related_item_title.size
    css_new_title = "hydrus_item_related_item_title_#{i}"
    css_new_url   = "hydrus_item_related_item_url_#{i}"
    css_delete    = "remove_relatedItem_#{i}"
    url           = "http://library.stanford.edu"
    title         = "Library Website"
    # Got to edit page.
    login_as('archivist1')
    should_visit_edit_page(@hi)
    # Check for the related item input fields.
    (0...i).each do |j|
      page.should have_css("input#hydrus_item_related_item_title_#{j}")
      page.should have_css("input#hydrus_item_related_item_url_#{j}")
      page.should have_css("#remove_relatedItem_#{j}")
    end
    page.should_not have_css("##{css_new_title}")
    page.should_not have_css("##{css_new_url}")
    page.should_not have_css("##{css_delete}")
    # Add a new related item
    click_button "add_link"
    page.should have_css("##{css_new_title}")
    page.should have_css("##{css_new_url}")
    page.should have_css("##{css_delete}")
    fill_in(css_new_title, :with => title)
    fill_in(css_new_url, :with => url)
    # Save.
    click_button "Save"
    page.should have_content(@notice)
    # Make sure the descMetadata has the expected N of relatedItem nodes.
    # At one point we had a bug where the new title and url were added
    # to the first node rather than the new empty node.
    @hi = Hydrus::Item.find(@hi.pid)
    @hi.descMetadata.find_by_terms(:relatedItem).size.should == i + 1
    # Revisit edit page and check for the values we just added.
    should_visit_edit_page(@hi)
    page.should have_css("##{css_delete}")
    find_field(css_new_title).value.should == title
    find_field(css_new_url).value.should == url
    # Delete the item we added.
    click_link css_delete
    current_path.should == edit_polymorphic_path(@hi)
    page.should_not have_css("##{css_new_title}")
    page.should_not have_css("##{css_new_url}")
    page.should_not have_css("##{css_delete}")
  end

  it "editing related content w/o titles" do
    # Save copy of the original datastreams.
    @druid = "druid:oo000oo0005"
    @hi    = Hydrus::Item.find(@druid)
    # Set up the new values for the fields we will edit.
    ni = hash2struct(
      :ri_title => 'My URL title',
      :ri_url   => 'http://stanford.and.son',
      :title_f  => "hydrus_item_related_item_title_0",
      :url_f    => "hydrus_item_related_item_url_0",
    )
    # Visit edit page.
    login_as('archivist1')
    should_visit_edit_page(@hi)
    # Make sure the object does not have the new content yet.
    old_title = find_field(ni.title_f).value
    old_url = find_field(ni.url_f).value
    old_title.should be_blank
    old_url.should_not == ni.ri_url
    # Submit some changes.
    fill_in ni.title_f, :with => ni.ri_title
    fill_in ni.url_f, :with => ni.ri_url
    click_button "Save"
    # Confirm new location and flash message.
    current_path.should == polymorphic_path(@hi)
    page.should have_content(@notice)
    # Confirm new content in fedora.
    @hi = Hydrus::Item.find(@druid)
    @hi.related_item_title.first.should == ni.ri_title
  end

  it "can edit preferred citation field" do
    citation_field = "hydrus_item_preferred_citation"
    new_pref_cit  = "new_citation_FOO"
    orig_pref_cit = @hi.preferred_citation

    login_as('archivist1')
    should_visit_edit_page(@hi)

    find_field(citation_field).value.strip.should == orig_pref_cit
    fill_in citation_field, :with => new_pref_cit
    click_button "Save"
    page.should have_content(@notice)

    # Confirm new content in fedora.
    @hi = Hydrus::Item.find(@druid)
    @hi.preferred_citation == new_pref_cit
  end

  it "Related citation adding and deleting" do

    new_citation         = "hydrus_item_related_citation_2"
    new_delete_button    = "remove_related_citation_2"
    new_citation_text    = " This is a citation for a related item! "

    login_as('archivist1')
    should_visit_edit_page(@hi)

    page.should have_css("textarea#hydrus_item_related_citation_0")
    page.should have_css("textarea#hydrus_item_related_citation_1")

    page.should_not have_css("textarea##{new_citation}")
    page.should_not have_css("##{new_delete_button}")

    click_button "add_related_citation"
    current_path.should == edit_polymorphic_path(@hi)

    page.should have_css("##{new_citation}")
    page.should have_css("##{new_delete_button}")

    fill_in(new_citation, :with => new_citation_text)

    click_button "Save"
    page.should have_content(@notice)

    should_visit_edit_page(@hi)

    page.should have_css("##{new_delete_button}")
    find_field(new_citation).value.strip.should == new_citation_text.strip

    # delete
    click_link new_delete_button

    current_path.should == edit_polymorphic_path(@hi)
    page.should_not have_css("##{new_citation}")
    page.should_not have_css("##{new_delete_button}")
  end

  it "should have editible license information once the parent collection's license is set to varies" do
    varies_radio           = "hydrus_collection_license_option_varies"
    collection_licenses    = "license_option_varies"
    new_collection_license = "CC BY Attribution"
    item_licenses          = "hydrus_item_license"
    new_item_license       = "PDDL Public Domain Dedication and License"

    # Item has expected rights.
    params = {:embargo_date=>'', :visibility=>'world', :license_code=>'cc-by'}
    check_emb_vis_lic(@hi,params)

    # Modify the collection to allow varying license.
    login_as('archivist1')
    should_visit_edit_page(Hydrus::Collection.find("druid:oo000oo0003"))
    choose varies_radio
    select(new_collection_license, :from => collection_licenses)
    click_button "Save"
    page.should have_content(@notice)

    # Item edit page should offer ability to select a license.
    should_visit_edit_page(@hi)
    page.should have_selector("##{item_licenses}")

    # Verify that the default license set at the collection-level is selected.
    within("select##{item_licenses}") do
      selected_license = find("optgroup/option[@selected='selected']").text
      selected_license.should == new_collection_license
    end

    # Select a different license, and save.
    select(new_item_license, :from => item_licenses)
    click_button "Save"
    page.should have_content(@notice)

    # Item has expected rights.
    @hi = Hydrus::Item.find @druid
    params = {:embargo_date => '', :visibility => 'world', :license_code => 'pddl'}
    check_emb_vis_lic(@hi,params)

    # Verify that the selected license is set.
    should_visit_edit_page(@hi)
    within("select##{item_licenses}") do
      selected_license = find("optgroup/option[@selected='selected']").text
      selected_license.should == new_item_license
    end
  end

  describe "role-protection" do

    before(:each) do
      @prev_mint_ids = config_mint_ids()
    end

    after(:each) do
      config_mint_ids(@prev_mint_ids)
    end

    it "action buttons should not be accessible to users with insufficient powers" do

      # Create an item.
      owner    = 'archivist1'
      reviewer = 'archivist5'
      viewer   = 'archivist7'
      hi = create_new_item()

      # Submit for approval.
      # A viewer should not see the button.
      b = @buttons[:submit_for_approval]
      login_as(viewer)
      should_visit_view_page(hi)
      page.should_not have_button(b)

      # But the owner should see the button.
      # Submit it for approval.
      login_as(owner)
      should_visit_view_page(hi)
      click_button(b)

      # Disapprove item.
      # A viewer should not see the button.
      b = @buttons[:disapprove]
      login_as(viewer)
      should_visit_view_page(hi)
      page.should_not have_button(b)

      # But the reviewer should see the button.
      # Disapprove the item.
      login_as(reviewer)
      should_visit_view_page(hi)
      fill_in "hydrus_item_disapproval_reason", :with => "Doh!"
      click_button(b)

      # Resubmit item.
      # A viewer should not see the button.
      b = @buttons[:resubmit]
      login_as(viewer)
      should_visit_view_page(hi)
      page.should_not have_button(b)

      # But the owner should see the button.
      # Resubmit the item.
      login_as(owner)
      should_visit_view_page(hi)
      click_button(b)

      # Approve item.
      # A viewer should not see the button.
      b = @buttons[:approve]
      login_as(viewer)
      should_visit_view_page(hi)
      page.should_not have_button(b)

      # But the reviewer should see the button.
      # Disapprove the item.
      login_as(reviewer)
      should_visit_view_page(hi)
      click_button(b)

      # Create another item, one not requiring review.
      hi = create_new_item(:requires_human_approval => 'no')

      # Publish directly.
      # A viewer should not see the button.
      b = @buttons[:publish_directly]
      login_as(viewer)
      should_visit_view_page(hi)
      page.should_not have_button(b)

      # But the owner should see the button.
      # Publish directly.
      login_as(owner)
      should_visit_view_page(hi)
      click_button(b)

    end

  end

  describe "embargo and visibility" do
    
    # An object's embargo status affects both the embargoMetadata
    # and rightsMetadata, as summarized here:
    #
    # embargoed = no
    #   embargoMetadata
    #     datastream should be empty
    #   rightsMetadata
    #     read access should = world|stanford
    #     should be no embargoReleaseDate node
    #
    # embargoed = yes
    #   embargoMetadata
    #     releaseAccess read node should = world|stanford
    #     status = embargoed
    #     releaseDate = DATE
    #   rightsMetadata
    #     read access = NONE
    #     embargoReleaseDate = DATE

    it "xxx" do
    end

  end

end
