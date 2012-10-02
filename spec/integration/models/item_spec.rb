require 'spec_helper'

describe(Hydrus::Item, :integration => true) do

  describe("Content metadata generation") do

    it "should be able to generate content metadata, returning blank when no files exist and setting content metadata stream to blank" do
      hi = Hydrus::Item.new
      hi.create_content_metadata.should == ''
      lambda{ hi.datastreams['contentMetadata'].content }.should raise_error
      hi.update_content_metadata
      hi.datastreams['contentMetadata'].content.should == ''
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
          <file id="pinocchio.htm"/>
        </resource>
        <resource id="oo000oo0001_2" sequence="2" type="file">
          <label>Main survey -- as plain text (extracted into CSV tables)</label>
          <file id="pinocchio.-punctuation_in=file.name.txt"/>
        </resource>
        <resource id="oo000oo0001_3" sequence="3" type="file">
          <label>Main survey -- as PDF (prepared May 17, 2012)</label>
          <file id="pinocchio characters tc in file name.pdf"/>
        </resource>
        <resource id="oo000oo0001_4" sequence="4" type="file">
          <label>Imagine this is a set of data samples</label>
          <file id="pinocchio_using_a_rather_long_filename-2012-05-17.zip"/>
        </resource>
      </contentMetadata>
      EOF
    end

  end

end