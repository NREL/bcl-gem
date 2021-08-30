# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
