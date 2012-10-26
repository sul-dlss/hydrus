require 'spec_helper'

describe Hydrus::Item do
  
  before(:each) do
    @hi = Hydrus::Item.new
    @workflow_xml = <<-END
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workflows objectId="druid:oo000oo0001">
        <workflow repository="dor" objectId="druid:oo000oo0001" id="hydrusAssemblyWF">
          <process version="1" lifecycle="registered" elapsed="0.0" attempts="0" datetime="1234" status="completed" name="start-deposit"/>
          <process version="1" elapsed="0.0" attempts="0" datetime="9999" status="completed" name="submit"/>
          <process version="1" elapsed="0.0" attempts="0" datetime="1234" name="approve"/>
          <process version="1" elapsed="0.0" attempts="0" datetime="1234" name="start-assembly"/>
        </workflow>
      </workflows>
    END
    @workflow_xml = noko_doc(@workflow_xml)
  end

  it "can exercise a stubbed version of create()" do
    # More substantive testing is done at integration level.
    druid = 'druid:BLAH'
    stubs = [
      :remove_relationship,
      :assert_content_model,
      :add_to_collection,
      :augment_identity_metadata,
    ]
    stubs.each { |s| @hi.should_receive(s) }
    @hi.should_receive(:save).with(:no_edit_logging => true)
    @hi.stub(:pid).and_return(druid)
    @hi.stub(:adapt_to).and_return(@hi)
    hc = Hydrus::Collection.new
    Hydrus::Collection.stub(:find).and_return(hc)
    Hydrus::GenericObject.stub(:register_dor_object).and_return(@hi)
    Hydrus::Item.create(hc.pid, 'USERFOO').pid.should == druid
  end

  it "can exercise a stubbed version of create when terms have already been accepted on another item" do
    # More substantive testing is done at integration level.
    druid = 'druid:BLAH'
    stubs = [
      :remove_relationship,
      :assert_content_model,
      :add_to_collection,
      :augment_identity_metadata,
    ]
    stubs.each { |s| @hi.should_receive(s) }
    @hi.should_receive(:save).with(:no_edit_logging => true)
    @hi.stub(:pid).and_return(druid)
    @hi.stub(:adapt_to).and_return(@hi)
    @hi.stub(:requires_terms_acceptance).and_return(false)
    hc = Hydrus::Collection.new
    Hydrus::Collection.stub(:find).and_return(hc)
    Hydrus::GenericObject.stub(:register_dor_object).and_return(@hi)
    new_item=Hydrus::Item.create(hc.pid, 'USERFOO')
    new_item.pid.should == druid
    new_item.terms_of_deposit_accepted?.should be true
  end

  it "should indicate blank item visibility if no metadata available" do
    @hi.visibility.should == []
  end

  it "should indicate item visibility with an embargo date in the future" do
    @hi.embargo_date='1/1/2100'
    @hi.visibility.should == []
  end
  
  it "should be able to add and remove an item from a collection" do
    collection_pid = 'druid:xx99xx9999'
    exp_uri        = "info:fedora/#{collection_pid}"

    # Initially, the item is not a member of a collection.
    @hi.relationships(:is_member_of).should == []
    @hi.relationships(:is_member_of_collection).should == []

    # Add it to a collection, and confirm the relationships.
    @hi.add_to_collection(collection_pid)
    @hi.relationships(:is_member_of).should == [exp_uri]
    @hi.relationships(:is_member_of_collection).should == [exp_uri]

    # Remove it from the collection, and confirm.
    @hi.remove_from_collection(collection_pid)
    @hi.relationships(:is_member_of).should == []
    @hi.relationships(:is_member_of_collection).should == []
  end

  describe "#files" do
    subject { Hydrus::Item.new }

    it "should retrieve ObjectFiles from the database" do
      m = mock()
      Hydrus::ObjectFile.should_receive(:find_all_by_pid).with(subject.pid, hash_including(:order => 'weight')).and_return(m)
      subject.files.should == m
    end
  end
  
  describe "#actors" do
    subject { Hydrus::Item.new }
    let(:descMetadata_xml) { <<-eos
     <mods xmlns="http://www.loc.gov/mods/v3">
          <name>
              <namePart>Angus</namePart>
              <role>
                <roleTerm>guitar</roleTerm>
              </role>
          </name>
          <name>
              <namePart>John</namePart>
              <role>
                <roleTerm>bass</roleTerm>
              </role>
          </name>
     </mods>
     eos
    }
    let(:descMetadata) { Hydrus::DescMetadataDS.from_xml(descMetadata_xml) }
    
    before(:each) do
      subject.stub(:descMetadata) { descMetadata }
    end

    it "should have the right number of items" do
      subject.actors.length.should == 2
      subject.actors.all? { |x| x.should be_a_kind_of(Hydrus::Actor) }
    end

    it "should have array-like accessors" do
      actor = subject.actors.first
      actor.name.should == "Angus"
      actor.role.should == "guitar"
    end

  end # describe #actors

  describe "#add_to_collection" do
    subject { Hydrus::Item.new }

    it "should add 'set' and 'collection' relations" do
      subject.should_receive(:add_relationship_by_name).with('set', 'info:fedora/collection_pid')
      subject.should_receive(:add_relationship_by_name).with('collection', 'info:fedora/collection_pid')
      subject.add_to_collection('collection_pid')
    end
  end

  describe "#remove_from_collection" do
    subject { Hydrus::Item.new }

    it "should remove 'set' and 'collection' relations" do
      subject.should_receive(:remove_relationship_by_name).with('set', 'info:fedora/collection_pid')
      subject.should_receive(:remove_relationship_by_name).with('collection', 'info:fedora/collection_pid')
      subject.remove_from_collection('collection_pid')
    end
  end
  
  describe "roleMetadata in the item" do
    subject { Hydrus::Item.find('druid:oo000oo0001') }
    it "should have a roleMetadata datastream" do
      subject.roleMetadata.should be_an_instance_of(Hydrus::RoleMetadataDS)
      subject.item_depositor_id.should == 'archivist1'
      subject.item_depositor_name.should == 'Archivist, One'
    end
  end

  describe "keywords" do

    before(:each) do
      @mods_start = '<mods xmlns="http://www.loc.gov/mods/v3">'
      xml = <<-EOF
        #{@mods_start}
          <subject><topic>divorce</topic></subject>
          <subject><topic>marriage</topic></subject>
        </mods>
      EOF
      @dsdoc = Hydrus::DescMetadataDS.from_xml(xml)
      @hi.stub(:descMetadata).and_return(@dsdoc)
    end

    it "keywords() should return expected values" do
      @hi.keywords.should == %w(divorce marriage)
    end

    it "keywords= should rewrite all <subject> nodes" do
      @hi.keywords = ' foo , bar , quux  '
      @dsdoc.ng_xml.should be_equivalent_to <<-EOF
        #{@mods_start}
          <subject><topic>foo</topic></subject>
          <subject><topic>bar</topic></subject>
          <subject><topic>quux</topic></subject>
        </mods>
      EOF
    end

    it "keywords= should not modify descMD if the keywords are same as existing" do
      kws = %w(foo bar)
      @hi.stub(:keywords).and_return(kws)
      @hi.should_not_receive(:descMetadata)
      @hi.keywords = kws.join(',')
    end

  end
  
  
  describe "item level APO information" do
    describe "visibility" do
      subject {Hydrus::Item.new}
      describe "immediate" do
        it "should remove the releaseAccess node from embargoMD" do
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "world"
          subject.embargoMetadata.ng_xml.to_s.should match(/<releaseAccess>/)
          subject.embargo = "immediate"
          subject.visibility = "world"
          subject.embargoMetadata.ng_xml.to_s.should match(/<releaseAccess\/>/)
        end
        it "should remove the embargo date from both the rightsMD and embargoMD" do
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "world"
          subject.embargoMetadata.ng_xml.to_s.should match(/<releaseDate>#{(Date.today + 2.days).beginning_of_day.utc.xmlschema}<\/releaseDate>/)
          subject.rightsMetadata.ng_xml.to_s.should match(/<embargoReleaseDate>#{(Date.today + 2.days).to_s}<\/embargoReleaseDate>/)
          subject.embargo = "immediate"
          subject.visibility = "world"
          subject.embargoMetadata.ng_xml.to_s.should_not match(/<releaseDate/)
          subject.rightsMetadata.ng_xml.to_s.should_not match(/<embargoReleaseDate/)
        end
        it "should set the current rightsMD to world readable for world" do
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "stanford"
          subject.embargoMetadata.ng_xml.to_s.should match(/<group>stanford<\/group>/)
          subject.rightsMetadata.read_access.machine.world.should == []
          subject.embargo = "immediate"
          subject.visibility = "world"
          subject.embargoMetadata.ng_xml.to_s.should_not match(/<group>stanford<\/group>/)
          subject.embargoMetadata.ng_xml.to_s.should match(/<releaseAccess\/>/)
          subject.rightsMetadata.read_access.machine.world.should == [""]
        end
        it "should set the given group in rightsMD and remove world readability for groups being set" do
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "stanford"
          subject.embargoMetadata.ng_xml.to_s.should match(/<world\/>/)
          subject.embargo = "immediate"
          subject.visibility = "stanford"
          subject.embargoMetadata.ng_xml.to_s.should_not match(/<world\/>/)
          subject.embargoMetadata.ng_xml.to_s.should match(/<releaseAccess\/>/)
          subject.rightsMetadata.read_access.machine.group.include?("stanford").should be_true
        end
      end
      
      describe "future" do
        it "should remove the world read access from rightsMD" do
          subject.embargo = "immediate"
          subject.visibility = "world"
          subject.rightsMetadata.ng_xml.to_s.should match(/<world\/>/)
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "world"
          subject.rightsMetadata.read_access.machine.world.should == []
          subject.embargoMetadata.ng_xml.to_s.should match(/<world\/>/)
        end
        it "should remove groups from the read access of the rightsMD" do
          subject.embargo = "immediate"
          subject.visibility = "stanford"
          subject.rightsMetadata.read_access.machine.group.include?("stanford").should be_true
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "stanford"
          subject.rightsMetadata.read_access.machine.group.include?("stanford").should be_false
          subject.embargoMetadata.ng_xml.to_s.should match(/<group>stanford<\/group>/)
        end
        it "should set the current embargoMD to world readable for world" do
          subject.embargo = "immediate"
          subject.visibility = "stanford"
          subject.rightsMetadata.read_access.machine.group.include?("stanford").should be_true
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "world"
          subject.embargoMetadata.ng_xml.to_s.should match(/<releaseAccess>/)
          subject.embargoMetadata.ng_xml.at_xpath("//access[@type='read']/machine/world").should_not be_nil
          subject.rightsMetadata.ng_xml.to_s.should_not match(/<group>stanford<\/group>/)
        end
        it "should set the given group in emargoMD and remove world readability for groups being set" do
          subject.embargo = "immediate"
          subject.visibility = "world"
          subject.rightsMetadata.read_access.machine.world.should == [""]
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "stanford"
          subject.rightsMetadata.read_access.machine.world.should == []
          subject.embargoMetadata.ng_xml.to_s.should match(/<releaseAccess>/)
          subject.embargoMetadata.ng_xml.at_xpath("//access[@type='read']/machine/group[text()='stanford']").should_not be_nil
          subject.rightsMetadata.read_access.machine.group.include?("stanford").should be_false
        end
        it "should set the embargo date in the rights and embargo datastreams" do
          subject.embargo = "future"
          subject.embargo_date = (Date.today + 2.days).strftime("%m/%d/%Y")
          subject.visibility = "stanford"
          subject.embargoMetadata.release_date.should == (Date.today + 2.days).beginning_of_day.utc.xmlschema
          subject.rightsMetadata.read_access.machine.embargo_release_date.first.should == (Date.today + 2.days).to_s
        end
      end
    end

    describe "embargo" do
      subject {Hydrus::Item.new}
      it "should store the embargo_release_date element in the XML properly" do
        subject.rightsMetadata.read_access.machine.embargo_release_date.should == []
        subject.embargo_date= "8/1/2012"
        subject.rightsMetadata.read_access.machine.embargo_release_date.should == ["2012-08-01"]
        subject.rightsMetadata.ng_xml.to_s.should match(/embargoReleaseDate/)
      end
      it "should remove the embargo release date if the immediate radio button is selected (embargo= 'immediate')" do
        subject.rightsMetadata.read_access.machine.embargo_release_date.should == []
        subject.embargo_date= "8/1/2012"
        subject.rightsMetadata.read_access.machine.embargo_release_date.should == ["2012-08-01"]
        subject.embargo= 'immediate'
        subject.visibility= "world"
        subject.rightsMetadata.read_access.machine.embargo_release_date.should == []
      end
      describe "date ranges" do
        it "should return today's date if there is no completed submit time in the workflowDataStream",:integration => true do
          subject.beginning_of_embargo_range.should == Date.today.strftime("%m/%d/%Y")
        end
        it "should return the submit time if one is available" do
          subject.stub(:submit_time).and_return(Date.strptime("08/01/2012", "%m/%d/%Y").to_s)
          subject.beginning_of_embargo_range.should == "08/01/2012"
        end

        it "should get the end date range properly based on the collection's APO" do
          subject.stub(:beginning_of_embargo_range).and_return("08/01/2012")
          subject.stub_chain([:collection, :apo, :embargo]).and_return("6 months")
          subject.end_of_embargo_range.should == "02/01/2013"
          subject.stub_chain([:collection, :apo, :embargo]).and_return("1 year")
          subject.end_of_embargo_range.should == "08/01/2013"
          subject.stub_chain([:collection, :apo, :embargo]).and_return("5 years")
          subject.end_of_embargo_range.should == "08/01/2017"
        end
      end
    end
    
    describe "license() and license=" do

      subject {Hydrus::Item.new}

      describe "license()" do

        it "Item-level license is present: just return it" do
          exp = 'foo COLL_LICENSE'
          subject.stub_chain(:collection, :license).and_return(exp)
          subject.license.should == exp
        end

        it "Item-level license is blank: return Collection-level license" do
          exp = 'foo ITEM_LICENSE'
          subject.stub_chain(:rightsMetadata, :use, :machine).and_return([exp])
          subject.license.should == exp
        end
        
      end

      it "should set the human readable version properly" do
        subject.rightsMetadata.use.human.first.should be_blank
        subject.license = "cc-by-nc"
        subject.rightsMetadata.use.human.first.should == "CC BY-NC Attribution-NonCommercial"
      end

      it "should set the type attribute properly depending on the license applied" do
         subject.rightsMetadata.use.human.first.should be_blank
         subject.license = "cc-by-nc"
         subject.rightsMetadata.ng_xml.to_s.should match(/type=\"creativeCommons\"/)
         subject.license = "odc-odbl"
         subject.rightsMetadata.ng_xml.to_s.should_not match(/type=\"creativeCommons\"/)
         subject.rightsMetadata.ng_xml.to_s.should match(/type=\"openDataCommons\"/)
      end

    end  
  end
        
  describe "class methods" do
    it "should provide an array of person roles" do
      Hydrus::Item.person_roles.should be_a Array
    end
  end

  describe "strip_whitespace_from_fields()" do
    
    before(:each) do
      xml = <<-eos
       <mods xmlns="http://www.loc.gov/mods/v3">
          <abstract>  Blah blah  </abstract>
          <titleInfo><title>  Learn VB in 21 Days  </title></titleInfo>
       </mods>
      eos
      dmd = Hydrus::DescMetadataDS.from_xml(xml)
      @hi = Hydrus::Item.new
      @hi.stub(:descMetadata).and_return(dmd)
    end

    it "should be able to call method on a Hydrus::Item to remove whitespace" do
      a = @hi.abstract
      t = @hi.title
      @hi.strip_whitespace_from_fields([:abstract, :title])
      @hi.abstract.should == a.strip
      @hi.title.should == t.strip
    end

  end

  describe "validations" do

    before(:each) do
      @exp = [
        :pid,
        :collection,
        :files,
        :title,
        :abstract,
        :contact,
        :terms_of_deposit,
        :release_settings,
        :actors
      ]
      @hi.instance_variable_set('@should_validate', true)
    end

    it "blank slate Item (should_validate=false) should include only two errors" do
      @hi.stub(:should_validate).and_return(false)
      @hi.valid?.should == false
      @hi.errors.messages.keys.should include(*@exp[0..1])
    end

    it "blank slate Item (should_validate=true) should include all errors" do
      @hi.valid?.should == false
      @hi.errors.messages.keys.should include(*@exp)
    end
    
    it "should provide an error when the embargo date is out of the collection's embargo range" do
      coll = mock("collection")
      item = Hydrus::Item.new
      item.instance_variable_set('@should_validate', true)
      coll.stub(:is_open).and_return(true)
      coll.stub(:embargo_option).and_return("varies")
      coll.stub_chain([:apo, :embargo]).and_return("1 year")
      item.stub(:collection).and_return(coll)
      item.embargo = "future"
      item.embargo_date = (Date.today + 2.years).strftime("%m/%d/%Y")
      item.valid?.should == false
      item.errors.messages.should have_key(:embargo_date)
      item.errors.messages[:embargo_date].first.should =~ /must be in the date range \d{2}\/\d{2}\/\d{4} - \d{2}\/\d{2}\/\d{4}/
    end
    
    it "fully populated Item should be valid" do
      dru = 'druid:ll000ll0001'
      @hi.stub(:collection_is_open).and_return(true)
      @hi.stub(:accepted_terms_of_deposit).and_return(true)
      @hi.stub(:reviewed_release_settings).and_return(true)
      @exp.each { |e| @hi.stub(e).and_return(dru) }
      @hi.stub_chain([:collection, :embargo_option]).and_return("varies")
      @hi.valid?.should == true
    end
    
  end

  it "collection_is_open() should return true only if the Item is in an open Collection" do
    n  = 0
    [true, false, nil].each do |stub_val|
      c    = double('collection', :is_open => stub_val)
      exp  = not(not(stub_val))
      n   += 1 unless exp
      @hi.stub(:collection).and_return(c)
      @hi.collection_is_open.should == exp
      @hi.errors.size.should == n
    end
  end

  it "can exercise discovery_roles()" do
    Hydrus::Item.discovery_roles.should be_instance_of(Hash)
  end

  it "can exercise tracked_fields()" do
    @hi.tracked_fields.should be_an_instance_of(Hash)
  end

  it "status()" do
    @hi.stub(:requires_human_approval).and_return("no")
    @hi.stub(:is_published).and_return(true)
    @hi.status.should == 'published'
    @hi.stub(:is_published).and_return(false)
    @hi.stub(:is_submitted_for_approval).and_return(false)    
    @hi.status.should == 'draft'
    @hi.stub(:is_submitted_for_approval).and_return(true)    
    @hi.status.should == 'waiting for approval'    
    @hi.stub(:requires_human_approval).and_return("yes")    
    @hi.stub(:disapproval_reason).and_return('it is crappola')    
    @hi.status.should == 'item returned'    
  end
  
  it "is_destroyable() should return the negative of is_published" do
    @hi.stub(:is_published).and_return(false)
    @hi.is_destroyable.should == true
    @hi.stub(:is_published).and_return(true)
    @hi.is_destroyable.should == false
  end

  it "content_directory()" do
    dru = 'oo000oo9999'
    @hi.stub(:pid).and_return("druid:#{dru}")
    @hi.content_directory.should == File.join(
      File.expand_path('public/uploads'),
      'oo/000/oo/9999',
      dru,
      'content'
    )
  end

  it "metadata_directory()" do
    dru = 'oo000oo9999'
    @hi.stub(:pid).and_return("druid:#{dru}")
    @hi.metadata_directory.should == File.join(
      File.expand_path('public/uploads'),
      'oo/000/oo/9999',
      dru,
      'metadata'
    )
  end

    
  describe "publish()" do

    # More substantive testing is done at integration level.

    it "if already published, just set titles" do
      @hi.stub(:workflow_step_is_done).and_return(true)
      exp_title = 'blah blah blah'
      @hi.title = exp_title
      @hi.should_not_receive(:approve)
      @hi.should_not_receive(:complete_workflow_step)
      @hi.stub(:save).and_return(true)
      @hi.publish
      @hi.identityMetadata.objectLabel.should == [exp_title]
      @hi.label.should == exp_title
    end
    
    it "if not published, should set titles and call approve" do
      @hi.stub(:workflow_step_is_done).and_return(false)
      @hi.stub(:requires_human_approval).and_return("no")
      exp_title = 'blah blah blah'
      @hi.title = exp_title
      @hi.should_receive(:complete_workflow_step).with('submit')
      @hi.should_receive(:approve)
      @hi.stub(:save).and_return(true)      
      @hi.publish
      @hi.identityMetadata.objectLabel.should == [exp_title]
      @hi.label.should == exp_title
    end
    
  end

  it "should indicate no files have been uploaded yet" do
    @hi.files_uploaded?.should == false
  end

  it "should indicate that release settings have not been reviewed yet" do
    @hi.reviewed_release_settings?.should == false
    @hi.reviewed_release_settings="true"
    @hi.reviewed_release_settings?.should == true    
  end

  it "should indicate that terms of deposit have not been accepted yet" do
    @hi.terms_of_deposit_accepted?.should == false
  end
  
  it "should indicate if we do not require terms acceptance if user already accepted terms" do
    @hi.stub(:accepted_terms_of_deposit).and_return(true)
    @hi.requires_terms_acceptance('archivist1').should be false
  end

  it "should indicate if we do require terms acceptance if user has never accepted terms on another item in the same collection" do
    @coll=Hydrus::Collection.new
    @coll.stub(:users_accepted_terms_of_deposit).and_return({'archivist3'=>'10-12-2008 00:00:00','archivist4'=>'10-12-2009 00:00:05'})    
    @hi.stub(:accepted_terms_of_deposit).and_return(false)
    @hi.stub(:collection).and_return(@coll)
    @hi.requires_terms_acceptance('archivist1').should be true
  end
  
  it "should indicate if we do require terms acceptance if user already accepted terms on another item in the same collection, but it was more than 1 year ago" do
    @coll=Hydrus::Collection.new
    @coll.stub(:users_accepted_terms_of_deposit).and_return({'archivist1'=>'10-12-2008 00:00:00','archivist2'=>'10-12-2009 00:00:05'})    
    @hi.stub(:accepted_terms_of_deposit).and_return(false)
    @hi.stub(:collection).and_return(@coll)
    @hi.requires_terms_acceptance('archivist1').should be true
  end

  it "should indicate if we do not require terms acceptance if user already accepted terms on another item in the same collection, and it was less than 1 year ago" do
    @coll=Hydrus::Collection.new
    @coll.stub(:users_accepted_terms_of_deposit).and_return({'archivist1'=>Time.now - 364.days,'archivist2'=>'10-12-2009 00:00:05'})    
    @hi.stub(:accepted_terms_of_deposit).and_return(false)
    @hi.stub(:collection).and_return(@coll)
    @hi.requires_terms_acceptance('archivist1').should be false
  end
  
  it "should accept the terms of deposit for a user" do
    @coll=Hydrus::Collection.new
    @coll.stub(:accept_terms_of_deposit)
    @hi.stub(:collection).and_return(@coll)   
    @hi.terms_of_deposit_accepted?.should == false 
    @hi.accepted_terms_of_deposit.should_not == 'true'
    @hi.accept_terms_of_deposit('archivist1')
    @hi.accepted_terms_of_deposit.should == 'true'
    @hi.terms_of_deposit_accepted?.should == true
  end
    
  it "embargo_date_is_correct_format() should add an error if embargo_date is bogus" do
    k = :embargo_date
    # Valid date.
    @hi.stub(k).and_return('12/31/2012')
    @hi.embargo_date_is_correct_format
    @hi.errors.messages.should_not include(k)
    # Invalid date.
    @hi.stub(k).and_return('blah!!')
    @hi.embargo_date_is_correct_format
    @hi.errors.messages.should include(k)
  end

  it "requires_human_approval() should delegate to the collection" do
    ["yes", "no", "yes"].each { |exp|
      @hi.stub_chain(:collection, :requires_human_approval).and_return(exp)
      @hi.requires_human_approval.should == exp
    }
  end

end
