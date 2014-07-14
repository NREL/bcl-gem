require 'spec_helper'

describe 'BCL API' do
  context '::Measure' do
    before :all do
      @cm = BCL::ComponentMethods.new
      @username = @cm.config[:server][:user][:username]
      @password = @cm.config[:server][:user][:password]
    end

    context 'and when logged in' do
      it 'should login if not logged in' do
        expect(@cm.logged_in).to eq(false)

        @res = @cm.login
        expect(@res.code).to eq('200')
        expect(@cm.session).to_not be_nil
      end

      it 'should be able to post new measure with ids set' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_example.tar.gz"
        valid, res = @cm.push_content(filename, true, 'nrel_measure')

        # todo: fix these as well
        # valid.should be_true
        # res["nid"].to_i.should be > 0
        # res["uuid"].should_not be_nil
      end
    end

    context 'and searching for measures (simple search, returns JSON only, API v2.0)' do
      before :all do
        query = nil
        filter = 'fq[]=bundle:nrel_measure&show_rows=3'
        @results = @cm.search(query, filter)
      end

      it 'should return a valid search' do
        puts "Measure search result was #{@results.inspect}"
        expect(@results[:result].count).to be > 0
        expect(@results[:result][0][:measure][:name]).to be_a String
      end

      it 'should return three results' do
        @results[:result].count.should eq(3)
      end

    end

    context 'and parsing measure metadata (5 NREL measures only)' do
      before :all do

        query = 'NREL'
        filter = 'show_rows=5' # search for NREL and limit results to 5
        @cm.login unless @cm.logged_in
        @retval = @cm.measure_metadata(query, filter, false)
      end

      it 'should complete without errors' do
        expect(@retval).not_to be_empty
      end

      it "created parsed measure directory and directory isn't empty" do
        test = true
        test = false if !File.exist?(@cm.parsed_measures_path) || Dir["#{@cm.parsed_measures_path}*/"].empty?
        expect(test).to eq(true)
      end

      it 'moved files to the new directory with a better name' do
        @retval.each do |r|
          expect(r).not_to be_nil
          expect(File.exist?(File.join(@cm.parsed_measures_path, r[:classname]))).to be true
          expect(File.exist?(File.join(@cm.parsed_measures_path, r[:classname], 'measure.json'))).to be true
        end
      end

      it 'have equal number of measures and jsons' do
        # count only measures with a measure.rb file (needed for creating the json)
        num_measures = Dir.glob("#{@cm.parsed_measures_path}*/measure.rb")
        puts "downloaded #{num_measures.size} measures"
        num_json = Dir.glob(@cm.parsed_measures_path + '*/measure.json')
        num_json.count.should eq(num_measures.count)
      end
    end

  end
end
