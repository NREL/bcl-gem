require 'spec_helper'
require 'rest_client'
require 'json/pure'
require 'libxml'

describe "BCL API" do
  context "::Measure" do
    before :all do
      @cm = BCL::ComponentMethods.new
      @username = @cm.config[:server][:user][:username]
      @password = @cm.config[:server][:user][:password]
    end

    context "when logged in" do
      before :all do
        @res = @cm.login
      end

      it "should return 200" do
        @res.code.should eq("200")
      end

      it "should have a valid session" do
        @cm.session.should_not be_nil
      end

      it "should be able to post new measure with ids set" do
        filename = "#{File.dirname(__FILE__)}/resources/measure_example.tar.gz"
        valid, res = @cm.push_content(filename, true, "nrel_measure")

        # todo: fix these as well
        #valid.should be_true
        #res["nid"].to_i.should be > 0
        #res["uuid"].should_not be_nil
      end
    end
  end
end
