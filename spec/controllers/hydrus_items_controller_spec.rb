require 'spec_helper'

describe HydrusItemsController, :type => :controller do

  # ROUTES and MAPPING.
  describe "Paths Generated by Custom Routes:" do

    it "should map items show correctly" do
      expect({ :get => "/items/abc" }).to route_to(
        :controller => 'hydrus_items',
        :action     => 'show',
        :id         => 'abc')
    end

    it "should map items destroy_value action correctly" do
      expect({ :get => "/items/abc/destroy_value" }).to route_to(
        :controller => 'hydrus_items',
        :action     => 'destroy_value',
        :id         => 'abc')
    end

    it 'routes publish_directly action correctly' do
      expect(post: '/items/publish_directly/abc123').to route_to(controller: 'hydrus_items', action: 'publish_directly', id: 'abc123')
    end
    it 'routes submit_for_approval action correctly' do
      expect(post: '/items/submit_for_approval/abc123').to route_to(controller: 'hydrus_items', action: 'submit_for_approval', id: 'abc123')
    end
    it 'routes approve action correctly' do
      expect(post: '/items/approve/abc123').to route_to(controller: 'hydrus_items', action: 'approve', id: 'abc123')
    end
    it 'routes disapprove action correctly' do
      expect(post: '/items/disapprove/abc123').to route_to(controller: 'hydrus_items', action: 'disapprove', id: 'abc123')
    end
    it 'routes open_new_version action correctly' do
      expect(post: '/items/open_new_version/abc123').to route_to(controller: 'hydrus_items', action: 'open_new_version', id: 'abc123')
    end

    it "should have the destroy_hydrus_item_value convenience url" do
      expect(destroy_hydrus_item_value_path("123")).to match(/items\/123\/destroy_value/)
    end

  end

  # SHOW ACTION.
  describe "Show Action", :integration => true do

    it "should redirect when not logged in" do
      @pid = 'druid:oo000oo0001'
      get(:show, :id => @pid)
      expect(response).to redirect_to new_user_session_path
    end

  end

  describe "New Action", :integration => true do

    it "should restrict access to non authed user" do
      sign_in(mock_user)
      get(:new, :collection => "druid:oo000oo0003")
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not authorized to access this page.")
    end

    it "should redirect w/ a flash error when no collection has been provided" do
      sign_in(mock_authed_user)
      get :new
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to match(/You cannot create an item without specifying a collection./)
    end

  end

  describe "Update Action" do

    describe("File upload", :integration => true) do

      before(:all) do
        @pid = "druid:oo000oo0001"
        @file = fixture_file_upload("/../../spec/fixtures/files/fixture.html", "text/html")
      end

      it "should update the file successfully" do
        sign_in(mock_authed_user)
        put :update, :id => @pid, "files" => [@file]
        expect(response).to redirect_to(hydrus_item_path(@pid))
        expect(flash[:notice]).to match(/Your changes have been saved/)
        expect(flash[:notice]).to match(/&#39;fixture.html&#39; uploaded/)
        expect(Hydrus::Item.find(@pid).files.map{|file| file.filename }.include?("fixture.html")).to be_truthy
      end

    end

  end

  describe "Index action" do

    it "should redirect with a flash message when we're not dealing w/ a nested resrouce" do
      get :index
      expect(flash[:alert]).to eq("You need to sign in or sign up before continuing.")
      expect(response).to redirect_to(new_user_session_path)
    end

    describe "as a nested resource of a collection" do

      it "should return the collection requested via the hydrus_collection_id parameter and assign it to the fobj instance variable" do

        sign_in(mock_authed_user)
        mock_coll = double("HydrusCollection")
        expect(mock_coll).to receive(:"current_user=")
        expect(mock_coll).to receive(:items_list)
        allow(Hydrus::Collection).to receive(:find).and_return(mock_coll)
        controller.current_ability.can :read, mock_coll
        get :index, :hydrus_collection_id=>"1234"
        expect(response).to be_success
        expect(assigns(:fobj)).to eq(mock_coll)
      end

      it "should restrict access to authorized users" do
        sign_in(mock_user)
        allow(Hydrus::Collection).to receive(:find).and_return(double("", :current_user= => nil))
        get :index, :hydrus_collection_id => "12345"
        expect(flash[:alert]).to eq("You are not authorized to access this page.")
        expect(response).to redirect_to(root_path)
      end

    end

  end

  describe '#publish_directly', integration: true do
    it 'raises an exception if the user lacks the required permissions' do
      sign_in(mock_user)
      post(:publish_directly, id: 'druid:oo000oo0001')
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
      expect(response).to redirect_to(root_path)
    end
  end

  describe '#submit_for_approval', integration: true do
    it 'raises an exception if the user lacks the required permissions' do
      sign_in(mock_user)
      post(:submit_for_approval, id: 'druid:oo000oo0001')
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
      expect(response).to redirect_to(root_path)
    end
  end

  describe '#approve', integration: true do
    it 'raises an exception if the user lacks the required permissions' do
      sign_in(mock_user)
      post(:approve, id: 'druid:oo000oo0001')
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
      expect(response).to redirect_to(root_path)
    end
  end

  describe '#disapprove', integration: true do
    it 'raises an exception if the user lacks the required permissions' do
      sign_in(mock_user)
      post(:disapprove, id: 'druid:oo000oo0001')
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
      expect(response).to redirect_to(root_path)
    end
  end

  describe '#resubmit', integration: true do
    it 'raises an exception if the user lacks the required permissions' do
      sign_in(mock_user)
      post(:resubmit, id: 'druid:oo000oo0001')
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
      expect(response).to redirect_to(root_path)
    end
  end

  describe '#open_new_version', integration: true do
    it 'raises an exception if the user lacks the required permissions' do
      sign_in(mock_user)
      post(:open_new_version, id: 'druid:oo000oo0001')
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
      expect(response).to redirect_to(root_path)
    end
  end
end
