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
        expect(@results[:result].count).to eq 3
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
        expect(num_json.count).to eq num_measures.count
      end
    end

    context 'and uploading measures' do
      before :all do
        @cm.login unless @cm.logged_in
      end

      it 'should fail with malformed UUID' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_example.tar.gz"
        expect { @cm.update_content(filename, false, '1234-1234') }.to raise_error 'uuid of 1234-1234 is invalid'
      end

      it 'should NOT upload the measure as it already exists' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_example.tar.gz"
        valid, res = @cm.push_content(filename, false, 'nrel_measure')

        expect(valid).to eq false
        expect(res['form_errors']['field_tar_file']).to eq 'There is already content with that UUID.'
      end

      it 'should be able to update the measure' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_example.tar.gz"
        valid, res = @cm.update_content(filename, false)
        puts res.inspect

        expect(valid).to eq true
        expect(res['nid']).to eq '69197'
        expect(res['uuid']).to eq 'a5be6c96-4ecc-47fa-8d32-f4216ebc2e8f'
        # needs to return version id
      end

      it "should not be able to update a measure that doesn't already exist" do
        filename = "#{File.dirname(__FILE__)}/resources/non_uploaded_measure.tar.gz"
        valid, res = @cm.update_content(filename, false)

        expect(valid).to eq false
        expect(res).to eq ['Node  not found'] # TODO: this should be JSON, and fix the double space
      end
    end

    context 'BSD Tarball' do
      before :all do
        @cm.login unless @cm.logged_in
      end

      it 'should cause errors' do
        filename = "#{File.dirname(__FILE__)}/resources/bsd_created_measure.tar.gz"
        valid, res = @cm.push_content(filename, false, 'nrel_measure')

        expect(valid).to eq false
        expect(res[:error]).to eq 'returned 200, but returned body was empty'
      end
    end
  end
end
