require 'spec_helper'

# A mock class to use while testing out mixin.
class MockSolrQueryable
  include Hydrus::SolrQueryable
end

describe Hydrus::SolrQueryable do

  before(:each) do
    @msq  = MockSolrQueryable.new
    @hsq  = Hydrus::SolrQueryable
    @user = 'userFoo'
    @role_md_clause = %Q<roleMetadata_role_person_identifier_t:"#{@user}">
  end

  describe "add_involved_user_filter() modifies the SOLR :fq parameters" do

    it "should do nothing if there is no user" do
      h = {}
      @hsq.add_involved_user_filter(h, nil)
      h[:fq].should == nil
    end

    it "should add the expected :fq clause" do
      tests = [
        [ false, {},                [@role_md_clause] ],
        [ true,  {},                [@role_md_clause] ],
        [ false, {:fq => []},       [@role_md_clause] ],
        [ true,  {:fq => []},       [@role_md_clause] ],
        [ false, {:fq => ['blah']}, ['blah', @role_md_clause] ],
        [ true,  {:fq => ['blah']}, ["blah OR #{@role_md_clause}"] ],
      ]
      tests.each do |use_or, h, exp|
        @hsq.add_involved_user_filter(h, @user, :or => use_or)
        h[:fq].should == exp
      end
    end

  end

  describe "add_governed_by_filter() modifies the SOLR :fq parameters" do

    it "should do nothing if no druids are supplied" do
      h = {}
      @hsq.add_governed_by_filter(h, [])
      h[:fq].should == nil
    end

    it "should add the expected :fq clause" do
      druids = %w(aaa bbb)
      igb    = 'is_governed_by_s:("info:fedora/aaa" OR "info:fedora/bbb")'
      tests  = [
        [ {},                [igb] ],
        [ {:fq => []},       [igb] ],
        [ {:fq => ['blah']}, ['blah', igb] ],
      ]
      tests.each do |h, exp|
        @hsq.add_governed_by_filter(h, druids)
        h[:fq].should == exp
      end
    end

  end

  describe "add_model_filter() modifies the SOLR :fq parameters" do

    it "should do nothing if no models are supplied" do
      h = {}
      @hsq.add_model_filter(h)
      h[:fq].should == nil
    end

    it "should add the expected :fq clause" do
      models = %w(xxx yyy)
      hms    = 'has_model_s:("info:fedora/afmodel:xxx" OR "info:fedora/afmodel:yyy")'
      tests  = [
        [ {},                [hms] ],
        [ {:fq => []},       [hms] ],
        [ {:fq => ['blah']}, ['blah', hms] ],
      ]
      tests.each do |h, exp|
        @hsq.add_model_filter(h, *models)
        h[:fq].should == exp
      end
    end

  end

  it "squery_*() methods should return hashes of SOLR query parameters with expected keys" do
    # No need to check in greater details, because all of the detailed
    # work is done by methods already tested.
    h = @msq.squery_apos_involving_user(@user)
    Set.new(h.keys).should == Set.new([:rows, :fl, :q, :fq])
    h = @msq.squery_collections_of_apos(['a', 'b'])
    Set.new(h.keys).should == Set.new([:rows, :fl, :q, :fq])
    h = @msq.squery_item_counts_of_collections(['c', 'd'])
    Set.new(h.keys).should == Set.new([:rows, :fl, :q, :facet, :'facet.pivot', :fq])
    h = @msq.squery_all_hydrus_collections()
    Set.new(h.keys).should == Set.new([:rows, :fl, :q, :fq])
  end

  it "can exercise get_druids_from_response()" do
    k    = 'identityMetadata_objectId_t'
    exp  = [12, 34, 56]
    docs = exp.map { |n| {k => [n]} }
    resp = double('resp', :docs => docs)
    @msq.get_druids_from_response(resp).should == exp
  end

  # Note: These are integration tests.
  describe("all_hydrus_objects()", :integration => true) do

    before(:each) do
      @all_objects = [
        {:pid=>"druid:oo000oo0001", :object_type=>"Item",              :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0002", :object_type=>"AdminPolicyObject", :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0003", :object_type=>"Collection",        :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0004", :object_type=>"Collection",        :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0005", :object_type=>"Item",              :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0006", :object_type=>"Item",              :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0007", :object_type=>"Item",              :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0008", :object_type=>"AdminPolicyObject", :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0009", :object_type=>"AdminPolicyObject", :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0010", :object_type=>"Collection",        :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0011", :object_type=>"Item",              :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0012", :object_type=>"Item",              :object_version=>"2013.02.26a"},
        {:pid=>"druid:oo000oo0013", :object_type=>"Item",              :object_version=>"2013.02.26a"}
      ]
    end

    it "should get all Hydrus objects, with the correct info" do
      got = @msq.all_hydrus_objects.sort_by { |h| h[:pid] }
      got.should == @all_objects
    end

    it "should get all Hydrus objects -- but only an array of PIDs" do
      got = @msq.all_hydrus_objects(:pids_only => true).sort
      exp = @all_objects.map { |h| h[:pid] }
      got.should == exp
    end

    it "should all Items and Collections, with the correct info" do
      ms = [Hydrus::Collection, Hydrus::Item]
      got = @msq.all_hydrus_objects(:models => ms).sort_by { |h| h[:pid] }
      exp = @all_objects.reject { |h| h[:object_type] == 'AdminPolicyObject' }
      got.should == exp
    end

  end

end
