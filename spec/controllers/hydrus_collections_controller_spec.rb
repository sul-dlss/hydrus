require 'spec_helper'

describe HydrusCollectionsController do

  describe "Index action" do

    it "should redirect with a flash message when we're not dealing w/ a nested resource" do
      get :index
      flash[:alert].should == "You need to sign in or sign up before continuing."
      response.should redirect_to(new_user_session_path)
    end
  end

  describe "Routes and Mapping" do

    it "should map collections show correctly" do
      { :get => "/collections/abc" }.should route_to(
        :controller => 'hydrus_collections',
        :action     => 'show',
        :id         => 'abc')
    end

    it "should map collections destroy_value action correctly" do
      { :get => "/collections/abc/destroy_value" }.should route_to(
        :controller => 'hydrus_collections',
        :action     => 'destroy_value',
        :id         => 'abc')
    end

    it "should have the destroy_hydrus_collection_value convenience url" do
      destroy_hydrus_collection_value_path("123").should match(/collections\/123\/destroy_value/)
    end

    it "should route collections/list_all correctly" do
      { :get => "/collections/list_all" }.should route_to(
        :controller => 'hydrus_collections',
        :action     => 'list_all')
    end

    it "custom post actions should route correctly" do
      pid = 'abc123'
      actions = %w(open close)
      actions.each do |a|
        h = { :post => "/collections/#{a}/#{pid}" }
        h.should route_to(:controller => 'hydrus_collections', :action => a, :id => pid)
      end
    end

  end

  describe "Show Action", :integration => true do

    it "should redirect the user when not logged in" do
      @pid = 'druid:oo000oo0003'
      get :show, :id => @pid
      response.should redirect_to new_user_session_path
    end


  end

  describe "Update Action", :integration => true do

    before(:all) do
      @pid = "druid:oo000oo0003"
    end

    it "should not allow a user to update an object if you do not have edit permissions" do
      sign_in(mock_user)
      put :update, :id => @pid
      response.should redirect_to(root_path)
      flash[:alert].should == "You are not authorized to access this page."
    end

  end

  describe "open/close", :integration => true do

    it "should raise exception if user lacks required permissions" do
      pid = "druid:oo000oo0003"
      sign_in(mock_user)
      [:open, :close].each do |action|
        post(action, :id => pid)

        flash[:alert].should == "You are not authorized to access this page."
      end
    end

  end

  describe "list_all", :integration => true do

    it "should redirect to root url for non-admins when not in development mode" do
      sign_in(mock_authed_user)
      get(:list_all)
      flash[:alert].should == "You are not authorized to access this page."
      response.should redirect_to(root_path)
    end

    it "should redirect to root path when not logged in" do
      get(:list_all)
      response.should redirect_to(new_user_session_path)
    end

    it "should render the page for users with sufficient powers" do
      controller.current_ability.can :list_all_collections, Hydrus::Collection
      sign_in(mock_authed_user)
      
      get(:list_all)
      assigns[:all_collections].should_not == nil
      response.should render_template(:list_all)
    end

  end

end
