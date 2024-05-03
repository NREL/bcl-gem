# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'spec_helper'
require 'faraday'
require 'logger'

describe 'BCL API' do
  context '::Component' do
    before :all do
      @cm = BCL::ComponentMethods.new

      # set up faraday object
      @logger = Logger.new('faraday.log')
      @faraday = Faraday.new(url: @cm.config[:server][:url]) do |faraday|
        faraday.request :url_encoded # form-encode POST params
        faraday.use Faraday::Response::Logger, @logger
        faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
      end

      # create connection to server api with multipart capabilities
      @faraday_multipart = Faraday.new(url: @cm.config[:server][:url]) do |faraday|
        faraday.request :multipart
        faraday.request :url_encoded # form-encode POST params
        faraday.use Faraday::Response::Logger, @logger
        faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
      end
    end

    context 'LEGACY API v2.0 - search component information (simple search, returns JSON-parsed hash with symbols only)' do
      before :all do
        query = 'ashrae.json'
        filter = 'fq[]=bundle:nrel_component&show_rows=3&api_version=2.0'
        @results = @cm.search(query, filter)
      end

      it 'should return a valid search' do
        # puts "Search results #{@results[:result]}"
        expect(@results[:result].count).to eq(3)
        expect(@results[:result][0][:component][:name]).to be_a String
      end

      it 'should return three results' do
        expect(@results[:result].count).to eq 3
      end

      it 'should return results in hash with symbols (even when querying in xml)' do
        query = 'ashrae.xml'
        filter = 'fq[]=bundle:nrel_component&show_rows=3'
        expect(@results[:result].count).to be > 0
        expect(@results[:result][0][:component][:name]).to be_a String
      end
    end

    context 'New API Syntax - search component information (simple search, returns JSON-parsed hash with symbols only)' do
      before :all do
        query = 'ashrae.json'
        filter = 'fq=bundle:component&show_rows=3'
        @results = @cm.search(query, filter)
      end

      it 'should return a valid search' do
        # puts "Search results #{@results[:result]}"
        expect(@results[:result].count).to eq(3)
        expect(@results[:result][0][:component][:name]).to be_a String
      end

      it 'should return three results' do
        expect(@results[:result].count).to eq 3
      end

      it 'should return results in hash with symbols (even when querying in xml)' do
        query = 'ashrae.xml'
        filter = 'fq=bundle:component&show_rows=3'
        expect(@results[:result].count).to be > 0
        expect(@results[:result][0][:component][:name]).to be_a String
      end
    end

    # search and iterate through all pages of API
    context 'and search component information (all results search, returns JSON-parsed hash with symbols only, API v2.0 only)' do
      before :all do
        query = 'ashrae.json'
        filter = 'fq=component_tags:Material&fq=bundle:component'
        all_pages_flag = true
        @results = @cm.search(query, filter, all_pages_flag)
      end

      it 'should return a valid search' do
        expect(@results[:result].count).to be > 0
        expect(@results[:result][0][:component][:name]).to be_a String
      end

      it 'should return over 200 results (to demonstrate iteration over pages)' do
        expect(@results[:result].count).to be > 0
      end
    end

    context 'Legacy Syntax API v2.0 - Download component' do
      before :all do
        query = 'ashrae'
        filter = 'fq[]=bundle:nrel_component&show_rows=3'

        @results = @cm.search(query, filter)
        @uids = []
        @results[:result].each do |result|
          @uids << result[:component][:uuid]
        end
      end

      it 'should have uuid to download' do
        expect(@uids.length).to be > 0
      end

      it 'should be able to use get to download multiple components that is valid' do
        # need to look like uuids=abc,def
        data = "uids=#{@uids.join(',')}"

        res = @faraday.get "/api/component/download?#{data}"
        expect(res.status).to eq(200)
        expect(res.body).not_to be_nil
      end

      it 'should be able to download many components using get' do
        data = "uids=#{@uids.first}"

        res = @faraday.get "/api/component/download?#{data}"
        expect(res.status).to eq(200)
        expect(res.body).not_to be_nil
      end
    end

    context 'New Syntax - Download component' do
      before :all do
        query = 'ashrae'
        filter = 'fq=bundle:component&show_rows=3'

        @results = @cm.search(query, filter)
        @uids = []
        @results[:result].each do |result|
          @uids << result[:component][:uuid]
        end
      end

      it 'should have uuid to download' do
        expect(@uids.length).to be > 0
      end

      it 'should be able to use get to download multiple components that is valid' do
        # need to look like uuids=abc,def
        data = "uids=#{@uids.join(',')}"

        res = @faraday.get "/api/component/download?#{data}"
        expect(res.status).to eq(200)
        expect(res.body).not_to be_nil
      end

      it 'should be able to download many components using get' do
        data = "uids=#{@uids.first}"

        res = @faraday.get "/api/component/download?#{data}"
        expect(res.status).to eq(200)
        expect(res.body).not_to be_nil
      end
    end
  end
end
