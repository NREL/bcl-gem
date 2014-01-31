require 'spec_helper'

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

    context "and searching for measures (simple search, returns JSON only, API v2.0)" do
      before :all do
        query = nil
        filter = "fq[]=bundle:nrel_measure&show_rows=3"
        @results = @cm.search(query, filter)
      end

      it "should return a valid search" do

        @results[:result].count.should be > 0
        test = true
        test = false if !@results[:result][0][:measure][:name].is_a? String
        test.should be_true
      end

      it "should return three results" do
        @results[:result].count.should eq(3)
      end

    end

    context "and parsing measure metadata (5 NREL measures only)" do
      before :all do

        #search for NREL and limit results to 5
        @retval = false
        query = 'NREL'
        filter = 'show_rows=5'
        @retval = @cm.measure_metadata(query, filter, false)
      end

      it "should complete without errors"  do
        @retval.should be_true
      end

      it "created parsed measure directory and directory isn't empty" do
        test = true
        test = false if !File.exists?(@cm.parsed_measures_path) or Dir["#{@cm.parsed_measures_path}*/"].empty?
        expect(test).to be_true
      end

      it "created measure.json metadata files" do
        #count only measures with a measure.rb file (needed for creating the json)
        numMeasures = Dir.glob("#{@cm.parsed_measures_path}*/measure.rb")
        puts "downloaded #{numMeasures.size} measures"
        numJson = Dir.glob(@cm.parsed_measures_path + "*/measure.json")
        numJson.count.should eq(numMeasures.count)
      end
    end

  end
end
