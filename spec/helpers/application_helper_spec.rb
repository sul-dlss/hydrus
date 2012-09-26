require 'spec_helper'

describe ApplicationHelper do

  include ApplicationHelper

  it "should get the local application name" do
    application_name.should == "Stanford Digital Repository"
  end

  it "should be able to exercise both branches of hydrus_format_date()" do
    hydrus_format_date('').should == ''
    hydrus_format_date('1999-03-31').should == 'Mar 31, 1999'
  end

  it "seen_beta_dialog? should be shown only once" do
    # Initially, we haven't seen the dialog.
    session[:seen_beta_dialog] = false
    seen_beta_dialog?.should == false
    # After seeing dialog, the flag is true.
    session[:seen_beta_dialog].should == true
    seen_beta_dialog?.should == true
  end

  it "formatted_datetime() should return formatted date strings" do
    tests = [
      ['2012-08-10T06:11:57-0700', :date,     '10-Aug-2012'],
      ['2012-08-10T06:11:57-0700', :time,     '06:11 am'],
      ['2012-08-10T06:11:57-0700', :datetime, '10-Aug-2012 06:11 am'],
      ['blah'                    , nil,        nil],
      [nil                       , nil,        nil],
    ]
    tests.each do |input, fmt, exp|
      formatted_datetime(input, fmt).should == exp
    end
  end
  
  describe "render helpers" do
    describe "render_contextual_navigation" do
      it "should return the correct data" do
        @document_fedora = Hydrus::Collection.new(:pid=>"1234")
        helper.should_receive(:polymorphic_path).with(@document_fedora).and_return("")
        helper.should_receive(:edit_polymorphic_path).with(@document_fedora).and_return("")
        helper.should_receive(:polymorphic_path).with([@document_fedora,:items]).and_return("")
        helper.should_receive(:polymorphic_path).with([@document_fedora,:events]).and_return("")
        nav = Capybara.string(render_contextual_navigation(@document_fedora))
        nav.should have_css("ul.nav.nav-tabs li a")
        ["View Collection", "Edit Collection", "Items", "History"].each do |text|
          nav.should have_content(text)
        end
      end
    end
  end

end
