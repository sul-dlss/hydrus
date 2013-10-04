require 'spec_helper'

describe("Item create", :type => :request, :integration => true) do

  before(:all) do
    @div_alert   = "#flash-notices div.alert"
    @span_status = 'span#status-label'
    @div_actions = "div.collection-actions"
    @notices = {
      :save                => "Your changes have been saved.",
      :publish_directly    => "Item published: v",
      :submit_for_approval => "Item submitted for approval.",
      :approve             => "Item approved and published: v",
      :disapprove          => "Item returned.",
      :resubmit            => "Item resubmitted for approval.",
    }
    @status_msgs = {
      :draft             => "Draft",
      :awaiting_approval => "Waiting for approval",
      :returned          => "Item returned",
      :published         => "Published",
    }
    @buttons = {
      :add                 => 'Add',
      :save                => 'save_nojs',
      :add_contributor     => 'Add Contributor',
      :submit_for_approval => 'Submit for Approval',
      :resubmit            => 'Resubmit for Approval',
      :disapprove          => 'Return',
      :approve             => 'Approve and Publish',
      :publish_directly    => 'Publish',
    }
    @hc_druid = 'druid:oo000oo0003'
    @edit_path_regex = Regexp.new('/items/(druid:\w{11})/edit')
    # Need to mint an actual druid in order to pass validation.
    @prev_mint_ids = Dor::Config.configure.suri.mint_ids
    Dor::Config.configure.suri.mint_ids = true
  end

  after(:all) do
    # Restore mint_ids setting.
    Dor::Config.configure.suri.mint_ids = @prev_mint_ids
  end

  context "depositing items into collections" do
      it "should have a non-js select list for depositing items into collections" do
        login_as('archivist1')
        visit hydrus_collection_path(:id=>@hc_druid)
        select "data set", :from => "type"
        click_button("Add new item")
        current_path.should_not == hydrus_collection_path(:id=>@hc_druid)
        current_path.should =~ @edit_path_regex
      end

      it "should be able to access create-new-Item screen via the Collection view page" do
        Capybara.ignore_hidden_elements = false
        login_as('archivist1')
        collection = Hydrus::Collection.find(@hc_druid)
        visit polymorphic_path(collection)
        click_link 'data set'
        current_path.should =~ @edit_path_regex
        Capybara.ignore_hidden_elements = true
      end
    end

  it "should be able to create a new default Item type, with expected datastreams" do
    # Login, go to new Item page, and store the druid of the new Item.
    login_as('archivist1')
    visit new_hydrus_item_path(:collection => @hc_druid)
    current_path.should =~ @edit_path_regex
    druid = @edit_path_regex.match(current_path)[1]
    # Fill in form and save.
    fill_in "Title of item", :with => 'title_foo'
    fill_in "hydrus_item_contributors_0_name", :with => 'contributor_foo'
    fill_in "Abstract", :with => 'abstract_foo'
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])
    # Get Item out of fedora and confirm that our edits were persisted.
    item = Hydrus::Item.find(druid)
    item.title.should == 'title_foo'
    item.contributors.first.name.should == 'contributor_foo'
    item.abstract.should == 'abstract_foo'
    item.should be_instance_of Hydrus::Item
    item.create_date.should_not be_blank
    item.item_type.should == 'dataset'
    item.descMetadata.typeOfResource.should == ['software, multimedia']
    # Check workflow of Item.
    wf_nodes = item.workflows.find_by_terms(:workflow)
    wf_nodes.size.should == 1
    wf_nodes.first[:id].should == Dor::Config.hydrus.app_workflow.to_s
    # Check identityMetadata of Item.
    item.identityMetadata.tag.should include("Project : Hydrus")
    # Check roles of the Item.
    item.person_roles.should == { "hydrus-item-depositor" => Set.new(["archivist1"]) }
    # Check events.
    exp = [
      /\AItem created/,
      /\AItem modified/,
    ]
    es = item.get_hydrus_events
    es.size.should == exp.size
    es[0...exp.size].zip(exp).each do |e, exp|
      e.text.should =~ exp
      e.who.should == 'archivist1'
      e.type.should == 'hydrus'
    end
  end

  it "should be able to create a new article type Item, with expected datastreams" do
    # Login, go to new Item page, and store the druid of the new Item.
    login_as('archivist1')
    visit new_hydrus_item_path(:collection => @hc_druid, :type=>'article')
    current_path.should =~ @edit_path_regex
    druid = @edit_path_regex.match(current_path)[1]
    # Fill in form and save.
    fill_in "Title of item", :with => 'title_article'
    fill_in "hydrus_item_contributors_0_name", :with => 'contributor_article'
    fill_in "Abstract", :with => 'abstract_article'
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])
    # Get Item out of fedora and confirm that our edits were persisted.
    item = Hydrus::Item.find(druid)
    item.title.should == 'title_article'
    item.contributors.first.name.should == 'contributor_article'
    item.abstract.should == 'abstract_article'
    item.should be_instance_of Hydrus::Item
    item.create_date.should_not be_blank
    item.item_type.should == 'article'
    item.descMetadata.typeOfResource.should == ['text']
    item.descMetadata.genre.should == ['article']
  end
  
  it "should be able to create a new class project Item, with expected datastreams" do
    # Login, go to new Item page, and store the druid of the new Item.
    login_as('archivist1')
    visit new_hydrus_item_path(:collection => @hc_druid, :type=>'class project')
    current_path.should =~ @edit_path_regex
    druid = @edit_path_regex.match(current_path)[1]
    # Fill in form and save.
    fill_in "Title of item", :with => 'title_article'
    fill_in "hydrus_item_contributors_0_name", :with => 'contributor_article'
    fill_in "Abstract", :with => 'abstract_article'
    click_button(@buttons[:save])

    find(@div_alert).should have_content(@notices[:save])
    # Get Item out of fedora and confirm that our edits were persisted.
    item = Hydrus::Item.find(druid)
    item.title.should == 'title_article'
    item.contributors.first.name.should == 'contributor_article'
    item.abstract.should == 'abstract_article'
    item.should be_instance_of Hydrus::Item
    item.create_date.should_not be_blank
    item.item_type.should == 'class project'
    item.descMetadata.typeOfResource.should == ['text']
    item.descMetadata.genre.should == ['student project report']
  end


  it "Requires approval: should be able to submit, disapprove, resubmit, approve, etc" do
    # Setup.
    ni = hash2struct(
      :title       => 'title_foo',
      :abstract    => 'abstract_foo',
      :contact     => 'ozzy@hell.com',
      :reason      => 'Idiota',
      :contributor => 'contributor_foo',
      :keywords    => 'aaa,bbb',
      :date_created => '2011',
    )

    # Force Items to receive human approval.
    coll = Hydrus::Collection.find(@hc_druid)
    coll.requires_human_approval = 'yes'
    coll.save

    # Login as a item depositor for this collection, go to new Item page, and
    # store the druid of the new Item.
    login_as('archivist6')
    visit new_hydrus_item_path(:collection => @hc_druid)
    page.should have_content('Welcome archivist6!')
    current_path.should =~ @edit_path_regex
    druid = @edit_path_regex.match(current_path)[1]

    # Fill in form and save.
    fill_in "hydrus_item_contributors_0_name", :with => ni.contributor
    fill_in "Title of item", :with => ni.title
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])

    # The view page should display some validation error messages, and should
    # not offer the Submit for approval button.
    find(@div_actions).should_not have_button(@buttons[:submit_for_approval])
    find(@span_status).should have_content(@status_msgs[:draft])

    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'draft'
    item.is_draft == true
    item.is_awaiting_approval.should == false
    item.is_publishable.should == false
    item.is_published.should == false
    item.is_returned.should == false
    item.is_destroyable.should == true
    item.submitted_for_publish_time.should be_blank
    item.accepted_terms_of_deposit.should == "false"
    item.valid?.should == true  # Because unpublished, so validation is limited.

    # Go back to edit page and fill in required elements.
    should_visit_edit_page(item)
    check "release_settings"
    fill_in "hydrus_item_abstract", :with => ni.abstract
    fill_in "hydrus_item_contact",  :with => ni.contact
    fill_in "hydrus_item_keywords", :with => ni.keywords
    fill_in "hydrus_item_date_created", :with => ni.date_created 
    f = Hydrus::ObjectFile.new
    f.pid = druid
    f.file = Tempfile.new('mock_HydrusObjectFile_')
    f.save
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])

    # The view page should still not offer the Submit for approval button since
    # we haven't accepted the terms.
    find(@div_actions).should_not have_button(@buttons[:submit_for_approval])

    # Accept terms of deposit
    should_visit_edit_page(item)
    check "terms_of_deposit_checkbox"
    click_button(@buttons[:save])

    # The view page should now offer the Submit for approval button (but no publish button) since we
    # have accepted the terms.
    visit hydrus_item_path(:id=>item.pid)
    find(@div_actions).should have_button(@buttons[:submit_for_approval])
    find(@div_actions).should_not have_button(@buttons[:publish_directly])

    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'draft'
    item.is_draft.should == true
    item.is_awaiting_approval.should == false
    item.is_publishable_directly.should == false    
    item.is_publishable.should == false
    item.is_submittable_for_approval.should == true
    item.submit_for_approval_time.should be_blank
    item.is_published.should == false
    item.is_returned.should == false
    item.is_destroyable.should == true
    item.valid?.should == true

    # Submit the Item for approval.
    click_button(@buttons[:submit_for_approval])
    find(@div_alert).should have_content(@notices[:submit_for_approval])

    # The view page should not offer the Submit for approval button or the publish button
    find(@div_actions).should_not have_button(@buttons[:submit_for_approval])
    find(@div_actions).should_not have_button(@buttons[:publish_directly])
    find(@span_status).should have_content(@status_msgs[:awaiting_approval])

    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'awaiting_approval'
    item.is_publishable.should == true
    item.is_publishable_directly.should == false
    item.requires_human_approval.should == "yes"
    item.is_published.should == false
    item.is_returned.should == false
    item.is_destroyable.should == true
    item.submitted_for_publish_time.should be_blank
    item.submit_for_approval_time.should_not be_blank
    item.valid?.should == true

    # Return to edit page, and try to save Item with an empty title.
    click_link "Edit Draft"
    fill_in "hydrus_item_title", :with => ''
    click_button(@buttons[:save])
    find(@div_alert).should_not have_content(@notices[:save])
    find(@div_alert).should have_content('Title cannot be blank')

    # Fill in the title and save.
    fill_in "hydrus_item_title", :with => ni.title
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])

    # now login as archivist 1 (collection manager) and Disapprove the Item.
    login_as('archivist1')
    visit hydrus_item_path(:id=>item.pid)
    page.should have_content('Welcome archivist1!')
    fill_in "hydrus_item_disapproval_reason", :with => ni.reason
    e = expect { click_button(@buttons[:disapprove]) }
    e.to change { ActionMailer::Base.deliveries.count }.by(1)

    find(@div_alert).should have_content(@notices[:disapprove])

    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'returned'
    item.is_publishable.should == false
    item.is_publishable_directly.should == false
    item.is_published.should == false
    item.is_returned.should == true
    item.is_destroyable.should == true
    item.valid?.should == true
    item.disapproval_reason.should == ni.reason
    visit hydrus_item_path(:id=>item.pid)
    find(@span_status).should have_content(@status_msgs[:returned])

    # now login as archivist 6 (depositor) and resubmit the Item.
    login_as('archivist6')
    visit hydrus_item_path(:id=>item.pid)
    page.should have_content('Welcome archivist6!')
    page.should have_content(ni.reason)
    find(@span_status).should have_content(@status_msgs[:returned])
    click_button(@buttons[:resubmit])
    find(@div_alert).should have_content(@notices[:resubmit])

    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'awaiting_approval'
    item.is_publishable.should == true
    item.is_publishable_directly.should == false
    item.is_published.should == false
    item.is_returned.should == false
    item.is_destroyable.should == true
    item.valid?.should == true
    item.disapproval_reason.should == nil
    find(@span_status).should have_content(@status_msgs[:awaiting_approval])

    # Now login as archivist 1 and approve the item.
    login_as('archivist1')
    visit hydrus_item_path(:id=>item.pid)
    click_button(@buttons[:approve])
    find(@div_alert).should have_content(@notices[:approve])

    # The view page should not offer the Publish, Approve, or Disapprove buttons.
    div_cs = find(@div_actions)
    div_cs.should_not have_button(@buttons[:submit_for_approval])
    div_cs.should_not have_button(@buttons[:approve])
    div_cs.should_not have_button(@buttons[:disapprove])
    find(@span_status).should have_content(@status_msgs[:published])

    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'published'
    item.is_publishable.should == false
    item.is_published.should == true
    item.is_returned.should == false
    item.is_destroyable.should == false
    item.valid?.should == true
    item.disapproval_reason.should == nil
    item.is_embargoed.should == false
    item.submitted_for_publish_time.should_not be_blank
    item.visibility.should == ["stanford"]
    ps={:visibility=>'stanford',:license_code=>'cc-by',:embargo_date=>''}
    check_emb_vis_lic(item,ps)

    # Check events.
    exp = [
      /\AItem created/,
      /\AItem modified/,
      /\AItem modified/,
      /\ATerms of deposit accepted/,
      /\AItem submitted for approval/,
      /\AItem returned/,
      /\AItem resubmitted for approval/,
      /\AItem approved/,
      /\AItem published/,
    ]
    es = item.get_hydrus_events
    es[0...exp.size].zip(exp).each { |e, exp| e.text.should =~ exp  }
  end

  it "Does not require approval: should be able to publish directly, with world visible rights and a different license than collection" do
    ni = hash2struct(
      :title       => 'title_foo',
      :abstract    => 'abstract_foo',
      :contact     => 'ozzy@hell.com',
      :reason      => 'Idiota',
      :contributor => 'contributor_foo',
      :keywords    => 'aaa,bbb',
      :date_created => '2011',
    )
    # Force Items to not receive human approval and have varied visiblity and licenses
    coll = Hydrus::Collection.find(@hc_druid)
    coll.requires_human_approval = 'no'
    coll.visibility_option_value = 'varies'
    coll.license = 'cc-by-sa'
    coll.license_option = 'varies'
    coll.save

    # Login as a item depositor for this collection, go to new Item page, and store the druid of the new Item.
    login_as('archivist1')
    visit new_hydrus_item_path(:collection => @hc_druid)
    current_path.should =~ @edit_path_regex
    druid = @edit_path_regex.match(current_path)[1]
    # Fill in form and save.
    fill_in "hydrus_item_contributors_0_name", :with => ni.contributor
    fill_in "Title of item", :with => ni.title
    select "everyone", :from => "hydrus_item_embarg_visib_visibility"
    select "CC BY-ND Attribution-NoDerivs", :from=>"hydrus_item_license"
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])
    # The view page should display some validation error messages, and should not
    # offer the Publish button.
    find(@div_actions).should_not have_button(@buttons[:publish_directly])
    find(@span_status).should have_content(@status_msgs[:draft])
    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'draft'
    item.is_publishable.should == false
    item.is_published.should == false
    item.is_returned.should == false
    item.is_destroyable.should == true
    item.accepted_terms_of_deposit.should == "false"
    item.valid?.should == true  # Because unpublished, so validation is limited.

    # Go back to edit page and fill in required elements.
    should_visit_edit_page(item)
    check "release_settings"
    fill_in "hydrus_item_abstract", :with => ni.abstract
    fill_in "hydrus_item_contact",  :with => ni.contact
    fill_in "hydrus_item_keywords", :with => ni.keywords
    fill_in "hydrus_item_date_created", :with => ni.date_created
    f = Hydrus::ObjectFile.new
    f.pid = druid
    f.file = Tempfile.new('mock_HydrusObjectFile_')
    f.save
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])
    # The view page should not offer the Publish button since we haven't accepted the terms yet
    find(@div_actions).should_not have_button(@buttons[:publish_directly])

    # Accept terms of deposit
    should_visit_edit_page(item)
    check "terms_of_deposit_checkbox"
    click_button(@buttons[:save])

    visit hydrus_item_path(:id=>item.pid)
    # now we should have the publish button
    find(@div_actions).should have_button(@buttons[:publish_directly])
    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'draft'
    item.is_publishable.should == true
    item.is_publishable_directly.should == true
    item.requires_human_approval.should == "no"
    item.is_submittable_for_approval.should == false
    item.is_published.should == false
    item.is_returned.should == false
    item.is_destroyable.should == true
    item.valid?.should == true
    # Publish thte item
    click_button(@buttons[:publish_directly])
    find(@div_alert).should have_content(@notices[:publish_directly])
    # The view page should not offer the Publish button.
    find(@div_actions).should_not have_button(@buttons[:publish_directly])
    find(@span_status).should have_content(@status_msgs[:published])
    # Check various Item attributes and methods.
    item = Hydrus::Item.find(druid)
    item.object_status.should == 'published'
    item.is_publishable.should == false
    item.is_published.should == true
    item.is_returned.should == false
    item.is_destroyable.should == false
    item.valid?.should == true
    ps={:visibility=>'world',:license_code=>'cc-by-nd',:embargo_date=>''}
    check_emb_vis_lic(item,ps)

    # Return to edit page, and try to save Item with an empty title.
    should_visit_edit_page(item)
    fill_in "hydrus_item_title", :with => ''
    click_button(@buttons[:save])
    find(@div_alert).should_not have_content(@notices[:save])
    find(@div_alert).should have_content('Title cannot be blank')
    # Fill in the title and save.
    fill_in "hydrus_item_title", :with => ni.title
    click_button(@buttons[:save])
    find(@div_alert).should have_content(@notices[:save])

    # Check events.
    exp = [
      /\AItem created/,
      /\AItem modified/,
      /\AItem modified/,
      /\ATerms of deposit accepted/,
      /\AItem published/,
    ]
    es = item.get_hydrus_events
    es[0...exp.size].zip(exp).each { |e, exp| e.text.should =~ exp  }
  end

  describe("terms of acceptance for an existing item", :integration => true)  do

    subject { Hydrus::Item.find('druid:oo000oo0001') }

    it "should indicate if the item has had terms accepted already" do
      subject.accepted_terms_of_deposit.should == "true"
      subject.terms_of_deposit_accepted?.should == true
    end

    it "should indicate the users who have accepted the terms of deposit for this collection in a hash and should returns dates accepted" do
      users=subject.collection.users_accepted_terms_of_deposit
      users.class.should == Hash
      users.size.should == 2
      users.keys.include?('archivist1').should == true
      users['archivist1'].should == '2011-09-02T09:02:32Z'
      users.keys.include?('archivist3').should == true
      users['archivist3'].should == '2012-05-02T20:02:44Z'
    end

  end

  describe("terms of acceptance for a new item",:integration => true)  do

    subject { Hydrus::Collection.find('druid:oo000oo0003') }

    it "should indicate that a new item in a collection requires terms acceptance, if the user has already accepted another item in this collection but it was more than 1 year ago" do
      u ='archivist1' # this user accepted more than 1 year ago
      subject.users_accepted_terms_of_deposit.keys.include?(u).should == true
      ni=Hydrus::Item.create(subject.pid, mock_authed_user(u))
      ni.requires_terms_acceptance(u,subject).should == true
      ni.accepted_terms_of_deposit.should == "false"
      ni.terms_of_deposit_accepted?.should == false
    end

    it "should indicate that a new item in a collection does not require terms acceptance, if the user has already accepted another item in this collection less than 1 year ago" do
      u='archivist3'
      dt = HyTime.now - 1.month # force this user to have accepted 1 month ago.
      subject.users_accepted_terms_of_deposit.keys.include?(u).should == true
      subject.hydrusProperties.accept_terms_of_deposit(u,HyTime.datetime(dt))
      subject.save
      ni=Hydrus::Item.create(subject.pid, mock_authed_user(u))
      ni.requires_terms_acceptance(u,subject).should == false
      ni.accepted_terms_of_deposit.should == "true"
      ni.terms_of_deposit_accepted?.should == true
    end

    it "should indicate that a new item in a collection requires terms acceptance, when the user has not already accepted another item in this collection" do
      u='archivist5'
      Hydrus::Authorizable.stub(:can_create_items_in).and_return(true)
      ni=Hydrus::Item.create(subject.pid,mock_authed_user(u))
      ni.requires_terms_acceptance(u,subject).should == true
      ni.accepted_terms_of_deposit.should == "false"
      ni.terms_of_deposit_accepted?.should == false
    end

    it "should accept the terms for an item, updating the appropriate hydrusProperties metadata in item and collection" do
      u    = 'archivist5'
      user = mock_authed_user(u)
      Hydrus::Authorizable.stub(:can_create_items_in).and_return(true)
      Hydrus::Authorizable.stub(:can_edit_item).and_return(true)
      ni=Hydrus::Item.create(subject.pid, user)
      ni.requires_terms_acceptance(u,subject).should == true
      ni.accepted_terms_of_deposit.should == "false"
      subject.users_accepted_terms_of_deposit.keys.include?(u).should == false
      ni.accept_terms_of_deposit(user)
      ni.accepted_terms_of_deposit.should == "true"
      ni.terms_of_deposit_accepted?.should == true
      coll=Hydrus::Collection.find('druid:oo000oo0003')
      coll.users_accepted_terms_of_deposit.keys.include?(u).should == true
      coll.users_accepted_terms_of_deposit[u].nil?.should == false
    end

  end

  describe "licenses" do

    before(:each) do
      @lic_select = 'select#hydrus_item_license'
    end

    it "collection: no license: new items should have no license" do
      login_as('archivist1')
      # Set collection to no-license mode.
      coll = Hydrus::Collection.find(@hc_druid)
      coll.license_option = 'none'
      coll.license = 'none'
      coll.save
      # Create a new item: page should not offer the license selector.
      druid = should_visit_new_item_page(@hc_druid)
      page.should_not have_css(@lic_select)
      page.should have_content('No license')
    end

    it "collection: fixed license: new items should have that license" do
      login_as('archivist1')
      # Set collection to fixed-license mode.
      coll = Hydrus::Collection.find(@hc_druid)
      coll.license_option = 'fixed'
      coll.license = 'cc-by-nd'
      coll.save
      # Create a new item: page should not offer the license selector.
      druid = should_visit_new_item_page(@hc_druid)
      page.should_not have_css(@lic_select)
      page.should have_content('CC BY-ND Attribution-NoDerivs')
    end

    describe "collection: variable license" do

      it "with a license: new items offer selector, with default selected" do
        login_as('archivist1')
        # Set collection to variable-license mode.
        coll = Hydrus::Collection.find(@hc_druid)
        coll.license_option = 'varies'
        coll.license = 'odc-by'
        coll.save
        # Create a new item: page should offer the license selector.
        druid = should_visit_new_item_page(@hc_druid)
        page.should have_css(@lic_select)
        within(@lic_select) {
          nodes = all('option[selected]')
          nodes.size.should == 1
          nodes.first.text.should == "ODC-By Attribution License"
        }
      end

      it "with no license: new items offer selector, with no-license selected" do
        login_as('archivist1')
        # Set collection to variable-license mode.
        coll = Hydrus::Collection.find(@hc_druid)
        coll.license_option = 'varies'
        coll.license = 'none'
        coll.save
        # Create a new item: page should offer the license selector.
        druid = should_visit_new_item_page(@hc_druid)
        page.should have_css(@lic_select)
        within(@lic_select) {
          nodes = all('option[selected]')
          nodes.size.should == 1
          nodes.first.text.should == "No license"
        }
      end

    end

  end

  describe "delete()" do

    it "should raise error if object is not destroyable" do
      hi = Hydrus::Item.find('druid:oo000oo0001')
      hi.is_destroyable.should == false
      expect { hi.delete }.to raise_error(RuntimeError)
    end

    it "should fully delete item: from fedora, solr, workflows, DB, and files" do
      # Setup.
      hyi = Hydrus::Item
      hyc = Hydrus::Collection
      afe = ActiveFedora::ObjectNotFoundError
      wfs = Dor::WorkflowService
      hwf = Dor::Config.hydrus.app_workflow.to_s
      # Create a new item.
      hi  = create_new_item()
      pid = hi.pid
      dir = hi.content_directory
      # Confirm existence of object:
      #   - in Fedora
      #   - in SOLR
      #   - in workflows
      hi.class.should == hyi
      hyc.all_hydrus_objects(:models => [hyi], :pids_only => true).should include(pid)
      wfs.get_workflows(pid).should == [hwf]
      #   - with an uploaded file
      #   - and a corresponding entry in DB table
      Dir.glob(dir + "/*").size.should == 1
      Hydrus::ObjectFile.find_all_by_pid(pid).size.should == 1
      # Delete the Item.
      hi.is_destroyable.should == true
      first(:link, "Discard this item").click
      click_button "Discard"
      hi = nil
      # Confirm that object was deleted:
      #   - from Fedora
      #   - from SOLR
      #   - from workflows
      expect { hyi.find(pid) }.to raise_error(afe)
      hyc.all_hydrus_objects(:models => [hyi], :pids_only => true).should_not include(pid)
      wfs.get_workflows(pid).should == []
      #   - with no upload directory
      #   - and no DB entries
      File.directory?(dir).should == false
      Hydrus::ObjectFile.find_all_by_pid(pid).size.should == 0
    end

  end

end