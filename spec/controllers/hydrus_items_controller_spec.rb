require 'spec_helper'

describe HydrusItemsController do

  # ROUTES and MAPPING.
  describe "Paths Generated by Custom Routes:" do

    it "should map items show correctly" do
      { :get => "/items/abc" }.should route_to(
        :controller => 'hydrus_items',
        :action     => 'show',
        :id         => 'abc')
    end

    it "should map items destroy_value action correctly" do
      { :get => "/items/abc/destroy_value" }.should route_to(
        :controller => 'hydrus_items',
        :action     => 'destroy_value',
        :id         => 'abc')
    end

    it "custom post actions should route correctly" do
      pid = 'abc123'
      actions = %w(
        publish_directly
        submit_for_approval
        approve
        disapprove
        open_new_version
      )
      actions.each do |a|
        h = { :post => "/items/#{a}/#{pid}" }
        h.should route_to(:controller => 'hydrus_items', :action => a, :id => pid)
      end
    end

    it "should have the destroy_hydrus_item_value convenience url" do
      destroy_hydrus_item_value_path("123").should match(/items\/123\/destroy_value/)
    end

  end

  # SHOW ACTION.
  describe "Show Action", :integration => true do

    it "should redirect when not logged in" do
      @pid = 'druid:oo000oo0001'
      controller.stub(:current_user).and_return(mock_user)
      get(:show, :id => @pid)
      response.should redirect_to root_path
    end

  end

  describe "New Action", :integration => true do

    it "should restrict access to non authed user" do
      controller.stub(:current_user).and_return(mock_user)
      get(:new, :collection => "druid:oo000oo0003")
      response.should redirect_to(root_path)
      flash[:error].should =~ /do not have sufficient privileges to create items in/
    end

    it "should redirect w/ a flash error when no collection has been provided" do
      controller.stub(:current_user).and_return(mock_authed_user)
      get :new
      response.should redirect_to(root_path)
      flash[:error].should =~ /You cannot create an item without specifying a collection./
    end

  end

  describe "Update Action" do

    describe("File upload", :integration => true) do

      before(:all) do
        @pid = "druid:oo000oo0001"
        @file = fixture_file_upload("/../../spec/fixtures/files/fixture.html", "text/html")
      end

      it "should update the file successfully" do
        controller.stub(:current_user).and_return(mock_authed_user)
        put :update, :id => @pid, "files" => [@file]
        response.should redirect_to(hydrus_item_path(@pid))
        flash[:notice].should =~ /Your changes have been saved/
        flash[:notice].should =~ /'fixture.html' uploaded/
        Hydrus::Item.find(@pid).files.map{|file| file.filename }.include?("fixture.html").should be_true
      end

    end

  end

  describe "Index action" do

    it "should redirect with a flash message when we're not dealing w/ a nested resrouce" do
      get :index
      flash[:warning].should =~ /You need to log in/
      response.should redirect_to(new_user_session_path)
    end

    describe "as a nested resource of a collection" do

      it "should return the collection requested via the hydrus_collection_id parameter and assign it to the fobj instance variable" do
        controller.stub(:current_user).and_return(mock_authed_user)
        mock_coll = double("HydrusCollection")
        mock_coll.should_receive(:"current_user=").and_return("")
        mock_coll.should_receive(:items_list)
        Hydrus::Collection.stub(:find).and_return(mock_coll)
        controller.stub(:'can?').and_return(true)
        get :index, :hydrus_collection_id=>"1234"
        response.should be_success
        assigns(:fobj).should == mock_coll
      end

      it "should restrict access to non authenticated users" do
        controller.stub(:current_user).and_return(mock_user)
        controller.stub(:'can?').and_return(false)
        get :index, :hydrus_collection_id => "12345"
        flash[:error].should =~ /You do not have permissions to view this collection/
        response.should redirect_to(root_path)
      end

    end

  end

  describe "custom actions: publish_directly, et al", :integration => true do

    it "should raise exception if user lacks required permissions" do
      pid = "druid:oo000oo0001"
      err_msg = /\ACannot perform action:/
      controller.stub(:current_user).and_return(mock_user)
      actions = [
        :publish_directly,
        :submit_for_approval,
        :approve,
        :disapprove,
        :resubmit,
        :open_new_version,
      ]
      actions.each do |action|
        e = expect { post(action, :id => pid) }
        e.to raise_exception(err_msg)
      end
    end

  end

end
