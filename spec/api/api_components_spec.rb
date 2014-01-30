require 'spec_helper'
require 'rest_client'
require 'json/pure'
require 'libxml'
require 'xml'

describe "BCL API" do
  context "::Component" do
    before :all do
      @cm = BCL::ComponentMethods.new
      @username = @cm.config[:server][:user][:username]
      @password = @cm.config[:server][:user][:password]
    end

    context "when bad login" do
      it "should not authenticate" do
        res = @cm.login(@username, "BAD_PASSWORD")
        res.code.should eq('401')
      end
    end

    context "when pushing components before logging in" do
      it "should raise exception" do
        expect {@cm.push_content("/dev/null", false, "nrel_component")}.to raise_exception
      end
    end

    context "when logged in" do
      before :all do
        @res = @cm.login
      end

      it "should return 200" do
        @res.code.should eq('200')
      end

      it "should have a valid session" do
        @cm.session.should_not be_nil
      end

      context "and search component information (simple search, returns JSON-parsed hash with symbols only, API v2.0 only)" do
        before :all do
          query = "ashrae.json"
          filter = "fq[]=bundle:nrel_component&show_rows=3"
          @results = @cm.search(query, filter)
        end

        it "should return a valid search" do
          @results[:result].count.should be > 0
          test = true
          test = false if !@results[:result][0][:component][:name].is_a? String
          test.should be_true
        end

        it "should return three results" do
          @results[:result].count.should eq(3)
        end

        it "should return results in hash with symbols (even when querying in xml)" do
          query = "ashrae.xml"
          filter = "fq[]=bundle:nrel_component&show_rows=3"
          @results[:result].count.should be > 0
          test = true
          test = false if !@results[:result][0][:component][:name].is_a? String
          test.should be_true
        end
      end

      #search and iterate through all pages of API
      context "and search component information (all results search, returns JSON-parsed hash with symbols only, API v2.0 only)"  do
        before :all do
          query = "ashrae.json"
          filter = "fq[]=sm_vid_Component_Tags:Material&fq[]=bundle:nrel_component"
          all_pages_flag = true
          @results = @cm.search(query, filter, all_pages_flag)
        end

        it "should return a valid search" do
          @results[:result].count.should be > 0
          test = true
          test = false if !@results[:result][0][:component][:name].is_a? String
          test.should be_true
        end

        it "should return over 200 results (to demonstrate iteration over pages)" do
          @results[:result].count.should be > 200
        end
      end

      context "and download component v2.0" do
        before :all do
          query = "ashrae"
          filter = "fq[]=bundle:nrel_component&show_rows=3"

          @results = @cm.search(query, filter)
          @uids = []
          @results[:result].each do |result|
            @uids << result[:component][:uuid]
          end
         end

        it "should have uuid to download" do
          @uids.length.should be > 0
        end

        it "should be able to use get to download multiple components that is valid" do
          # need to look like uuids=abc,def
          data = "uids=#{@uids.join(",")}"

          res = RestClient.get "#{@cm.config[:server][:url]}/api/component/download?#{data}"
          res.code.should eq(200)
          res.body.should_not be_nil
        end

        it "should be able to download many components using get" do
          data = "uids=#{@uids.first}"

          res = RestClient.get "#{@cm.config[:server][:url]}/api/component/download?#{data}"
          res.code.should eq(200)
          #res.code.should eq('200')
        end

        it "should be able to use post to download a component that is valid" do
          # need to look like uuids=abc,def
          data = "uids=#{@uids.first}"

          res = RestClient.post "#{@cm.config[:server][:url]}/api/component/download?#{data}", data
          res.code.should eq(200)
        end
      end

      context "post component" do
        it "should be able to post new component with no ids set" do
          filename = "#{File.dirname(__FILE__)}/resources/component_example_no_ids.tar.gz"
          valid, res = @cm.push_content(filename, true, "nrel_component")
          valid.should be_true
          res["nid"].to_i.should be > 0
          res["uuid"].should_not be_nil

        end

        it "should fail when posting a component with a non-unique uuid" do
          filename = "#{File.dirname(__FILE__)}/resources/component_example_no_vid.tar.gz"
          valid, res = @cm.push_content(filename, true, "nrel_component")

          puts res.inspect
          valid.should be_false
        end

        it "should fail when posting component with same uuid/vid components" do
          filename = "#{File.dirname(__FILE__)}/resources/component_example.tar.gz"
          valid, res = @cm.push_content(filename, true, "nrel_component")

          valid.should be_false
        end
      end

      context "posting multiple components" do
        it "should push 2 components" do
          files = Pathname.glob("#{File.dirname(__FILE__)}/resources/component_example_*.tar.gz")
          log = @cm.push_contents(files, false, "nrel_component")

          log.size.should eq(2)
        end

        it "should post 0 components when checking receipt files" do
          files = Pathname.glob("#{File.dirname(__FILE__)}/resources/component*.tar.gz")
          puts "FILES: #{files.inspect}"
          log = @cm.push_contents(files, true, "nrel_component")

          log.size.should eq(3)

          test = true
          log.each do |comp|
            test = false if !comp.include?("skipping") and !comp.include?("false")
          end
          test.should be_true
        end
      end

    end
  end
end
