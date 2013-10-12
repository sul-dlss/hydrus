require 'spec_helper'

describe(Hydrus::Item, :integration => true) do

  describe("Content metadata generation") do

    it "should be able to generate content metadata, returning blank CM when no files exist and setting content metadata stream to a blank template" do
      xml = "<contentMetadata objectId=\"__DO_NOT_USE__\" type=\"file\"/>"
      hi = Hydrus::Item.new
      hi.update_content_metadata
      hi.datastreams['contentMetadata'].content.should be_equivalent_to(xml)
    end

    it "should be able to generate content metadata, returning and setting correct cm when files exist" do
      item = Hydrus::Item.find('druid:oo000oo0001')
      item.files.size.should == 4
      item.datastreams['contentMetadata'].content.should be_equivalent_to "<contentMetadata></contentMetadata>"
      item.update_content_metadata
      item.datastreams['contentMetadata'].content.should be_equivalent_to <<-EOF
      <contentMetadata objectId="oo000oo0001" type="file">
        <resource id="oo000oo0001_1" sequence="1" type="file">
          <label>Main survey -- formatted in HTML</label>
          <file id="pinocchio.htm" preserve="yes" publish="yes" shelve="yes"/>
        </resource>
        <resource id="oo000oo0001_2" sequence="2" type="file">
          <label>Main survey -- as plain text (extracted into CSV tables)</label>
          <file id="pinocchio.-punctuation_in=file.name.txt" preserve="yes" publish="no" shelve="no"/>
        </resource>
        <resource id="oo000oo0001_3" sequence="3" type="file">
          <label>Main survey -- as PDF (prepared May 17, 2012)</label>
          <file id="pinocchio characters tc in file name.pdf" preserve="yes" publish="yes" shelve="yes"/>
        </resource>
        <resource id="oo000oo0001_4" sequence="4" type="file">
          <label>Imagine this is a set of data samples</label>
          <file id="pinocchio_using_a_rather_long_filename-2012-05-17.zip" preserve="yes" publish="yes" shelve="yes"/>
        </resource>
      </contentMetadata>
      EOF
    end

  end

  describe "do_publish()" do

    before(:each) do
      @prev_mint_ids = config_mint_ids()
    end

    after(:each) do
      config_mint_ids(@prev_mint_ids)
    end

    it "should modify workflows as expected" do
      # Setup.
      druid = 'druid:oo000oo0003'
      hi    = Hydrus::Item.create(druid, mock_authed_user)
      wf    = Dor::Config.hydrus.app_workflow
      steps = Dor::Config.hydrus.app_workflow_steps
      exp   = Hash[ steps.map { |s| [s, 'waiting'] } ]
      # Code to check workflow statuses.
      check_statuses = lambda {
        hi = Hydrus::Item.find(hi.pid)  # A refreshed copy of object.
        statuses = steps.map { |s| [s, hi.workflows.get_workflow_status(s)] }
        Hash[statuses].should == exp
      }
      # Initial statuses.
      exp['start-deposit'] = 'completed'
      check_statuses.call()
      # After running do_publish, with start_assembly_wf=true.
      hi.stub(:should_start_assembly_wf).and_return(true)
      hi.stub(:is_assemblable).and_return(true)
      Dor::WorkflowService.should_receive(:create_workflow).once
      hi.do_publish()
      exp['approve'] = 'completed'
      exp['start-assembly'] = 'completed'
      check_statuses.call()
    end

  end

  describe "create()" do

    before(:all) do
      @prev_mint_ids = config_mint_ids()
      Dor::WorkflowDs.any_instance.stub(:current_priority).and_return 0
      
      @collection = Hydrus::Collection.create mock_authed_user
    end

    after(:all) do
      @collection.delete
      config_mint_ids(@prev_mint_ids)
    end

    before(:each) do
      Hydrus::Collection.stub(:find).with(collection.pid).and_return(collection)
    end


    let(:collection) do
      @collection.stub(:is_open => true)
      @collection
    end

    it "should create an item" do
      collection.stub(:visibility_option_value => 'stanford', :license => 'some-license')
      item  = Hydrus::Item.create(collection.pid, mock_authed_user, 'some-type')
      item.should be_instance_of Hydrus::Item
      expect(item).to_not be_new
      expect(item.visibility).to include 'stanford'
      expect(item.item_type).to eq 'some-type'
      expect(item.events.event.val).to have(1).item
      expect(item.events.event).to include "Item created"
      expect(item.object_status).to eq 'draft'
      expect(item.versionMetadata).to_not be_new
      expect(item.license).to eq "some-license"
      expect(item.roleMetadata.item_depositor).to include mock_authed_user.sunetid
      expect(item.relationships(:has_model)).to include 'info:fedora/afmodel:Dor_Item'
      expect(item.relationships(:has_model)).to include 'info:fedora/afmodel:Hydrus_Item'
      expect(item.accepted_terms_of_deposit).to eq "false"
    end

    it "should create an item" do
      Dor::WorkflowDs.any_instance.stub(:current_priority).and_return 0
      collection.stub(:users_accepted_terms_of_deposit => { mock_authed_user.to_s => Time.now})

      item  = Hydrus::Item.create(collection.pid, mock_authed_user, 'some-type')
      item.should be_instance_of Hydrus::Item
      expect(item).to_not be_new
      expect(item.item_type).to eq 'some-type'
      expect(item.events.event).to include "Terms of deposit accepted due to previous item acceptance in collection"
      expect(item.accepted_terms_of_deposit).to eq "true"
    end
  end

end
