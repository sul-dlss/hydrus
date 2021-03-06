require 'spec_helper'

RSpec.describe Hydrus::SolrQueryable, type: :model do
  # A mock class to use while testing out mixin.
  let(:klass) do
    Class.new do
      include Hydrus::SolrQueryable
    end
  end

  let(:instance) { klass.new }
  let(:user) { 'userFoo' }

  let(:role_md_clause) do
    %Q<role_person_identifier_sim:"#{user}">
  end

  describe '.add_gated_discovery' do
    it 'should OR the facets for objects that involve the user and are governed by APOs the user has access to ' do
      h = {}
      described_class.add_gated_discovery(h, ['aaa', 'bbb'], user)
      expect(h[:fq].size).to eq(1)

      expect(h[:fq].first).to eq 'is_governed_by_ssim:("info:fedora/aaa" OR "info:fedora/bbb") OR ' + role_md_clause
    end
  end

  describe 'add_involved_user_filter() modifies the SOLR :fq parameters' do
    it 'should do nothing if there is no user' do
      h = {}
      described_class.add_involved_user_filter(h, nil)
      expect(h[:fq]).to eq(nil)
    end

    it 'should add the expected :fq clause' do
      tests = [
        [{}, [role_md_clause]],
        [{ fq: [] },       [role_md_clause]],
        [{ fq: ['blah'] }, ['blah', role_md_clause]],
      ]
      tests.each do |h, exp|
        described_class.add_involved_user_filter(h, user)
        expect(h[:fq]).to eq(exp)
      end
    end
  end

  describe 'add_governed_by_filter() modifies the SOLR :fq parameters' do
    it 'should do nothing if no druids are supplied' do
      h = {}
      described_class.add_governed_by_filter(h, [])
      expect(h[:fq]).to eq(nil)
    end

    it 'should add the expected :fq clause' do
      druids = %w(aaa bbb)
      igb    = 'is_governed_by_ssim:("info:fedora/aaa" OR "info:fedora/bbb")'
      tests  = [
        [{}, [igb]],
        [{ fq: [] },       [igb]],
        [{ fq: ['blah'] }, ['blah', igb]],
      ]
      tests.each do |h, exp|
        described_class.add_governed_by_filter(h, druids)
        expect(h[:fq]).to eq(exp)
      end
    end
  end

  describe 'add_model_filter() modifies the SOLR :fq parameters' do
    it 'should do nothing if no models are supplied' do
      h = {}
      described_class.add_model_filter(h)
      expect(h[:fq]).to eq(nil)
    end

    it 'should add the expected :fq clause' do
      models = %w(xxx yyy)
      hms    = 'has_model_ssim:("info:fedora/afmodel:xxx" OR "info:fedora/afmodel:yyy")'
      tests  = [
        [{}, [hms]],
        [{ fq: [] },       [hms]],
        [{ fq: ['blah'] }, ['blah', hms]],
      ]
      tests.each do |h, exp|
        described_class.add_model_filter(h, *models)
        expect(h[:fq]).to eq(exp)
      end
    end
  end

  it 'squery_*() methods should return hashes of SOLR query parameters with expected keys' do
    # No need to check in greater details, because all of the detailed
    # work is done by methods already tested.
    h = instance.squery_apos_involving_user(user)
    expect(Set.new(h.keys)).to eq(Set.new([:rows, :fl, :q, :fq]))
    h = instance.squery_collections_of_apos(['a', 'b'])
    expect(Set.new(h.keys)).to eq(Set.new([:rows, :fl, :q, :fq]))
    h = instance.squery_item_counts_of_collections(['c', 'd'])
    expect(Set.new(h.keys)).to eq(Set.new([:rows, :'facet.limit', :fl, :q, :facet, :'facet.pivot', :fq]))
    h = instance.squery_all_hydrus_collections()
    expect(Set.new(h.keys)).to eq(Set.new([:rows, :fl, :q, :fq]))
  end

  describe '#get_druids_from_response' do
    let(:resp_hash) { { 'docs' => exp.map { |n| { 'objectId_ssim' => [n] } } } }
    let(:resp) { instance_double(RSolr::HashWithResponse, fetch: resp_hash) }
    let(:exp) { [12, 34, 56] }

    it 'returns the document identifiers' do
      expect(instance.get_druids_from_response(resp)).to eq(exp)
    end
  end

  # Note: These are integration tests.
  describe('all_hydrus_objects()', integration: true) do
    before do
      @all_objects = [
        { pid: 'druid:bb000bb0002', object_type: 'AdminPolicyObject', object_version: '2013.02.26a' },
        { pid: 'druid:bb000bb0003', object_type: 'Collection',        object_version: '2013.02.26a' },
        { pid: 'druid:bb000bb0004', object_type: 'Collection',        object_version: '2013.02.26a' },
        { pid: 'druid:bb000bb0008', object_type: 'AdminPolicyObject', object_version: '2013.02.26a' },
        { pid: 'druid:bb000bb0009', object_type: 'AdminPolicyObject', object_version: '2013.02.26a' },
        { pid: 'druid:bb123bb1234', object_type: 'Item',              object_version: '2013.02.26a' },
        { pid: 'druid:bb123bb5432', object_type: 'Item',              object_version: '2013.02.26a' },
        { pid: 'druid:oo000oo0006', object_type: 'Item',              object_version: '2013.02.26a' },
        { pid: 'druid:oo000oo0007', object_type: 'Item',              object_version: '2013.02.26a' },
        { pid: 'druid:oo000oo0010', object_type: 'Collection',        object_version: '2013.02.26a' },
        { pid: 'druid:oo000oo0011', object_type: 'Item',              object_version: '2013.02.26a' },
        { pid: 'druid:oo000oo0012', object_type: 'Item',              object_version: '2013.02.26a' },
        { pid: 'druid:oo000oo0013', object_type: 'Item',              object_version: '2013.02.26a' }
      ]
    end

    it 'gets all Hydrus objects, with the correct info' do
      got = instance.all_hydrus_objects.sort_by { |h| h[:pid] }
      expect(got).to eq(@all_objects)
    end

    it 'get all Hydrus objects -- but only an array of PIDs' do
      got = instance.all_hydrus_objects(pids_only: true).sort
      exp = @all_objects.map { |h| h[:pid] }
      expect(got).to eq(exp)
    end

    it 'gets all Items and Collections, with the correct info' do
      ms = [Hydrus::Collection, Hydrus::Item]
      got = instance.all_hydrus_objects(models: ms).sort_by { |h| h[:pid] }
      exp = @all_objects.reject { |h| h[:object_type] == 'AdminPolicyObject' }
      expect(got).to eq(exp)
    end
  end

  describe 'queries should send their parameters via post' do
    it 'does not fail if the query is very long' do
      fake_pids = []
      1000.times do
        fake_pids << 'fake_pid'
      end
      h = instance.squery_item_counts_of_collections(fake_pids)
      # this raises a RSolr::Error::Http exception due to receiving a 414 error from solr unless the parameters are posted
      expect { resp, sdocs = instance.issue_solr_query(h) }.not_to raise_error
    end
  end
end
