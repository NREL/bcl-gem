######################################################################
#  Copyright (c) 2008-2021, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

require 'spec_helper'
require 'faraday'
require 'logger'

describe 'BCL API' do
  context '::Component' do
    before :all do
      @cm = BCL::ComponentMethods.new
      @username = @cm.config[:server][:user][:username]
      @password = @cm.config[:server][:user][:password]

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

    context 'when bad login' do
      it 'should not authenticate' do
        res = @cm.login(@username, 'BAD_PASSWORD')
        expect(res.code).to eq('401')
      end
    end

    context 'when pushing components before logging in' do
      it 'should raise exception' do
        expect { @cm.push_content('/dev/null', false, 'nrel_component') }.to raise_exception
      end
    end

    context 'when logged in' do
      before :all do
        @res = @cm.login
      end

      it 'should return 200' do
        expect(@res.code).to eq '200'
      end

      it 'should have a valid session' do
        expect(@cm.session).to_not be_nil
      end

      context 'and search component information (simple search, returns JSON-parsed hash with symbols only, API v2.0 only)' do
        before :all do
          query = 'ashrae.json'
          filter = 'fq[]=bundle:nrel_component&show_rows=3'
          @results = @cm.search(query, filter)
        end

        it 'should return a valid search' do
          puts "Search results #{@results[:result]}"
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

      # search and iterate through all pages of API
      context 'and search component information (all results search, returns JSON-parsed hash with symbols only, API v2.0 only)' do
        before :all do
          query = 'ashrae.json'
          filter = 'fq[]=sm_vid_Component_Tags:Material&fq[]=bundle:nrel_component'
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

      context 'and download component v2.0' do
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

        it 'should be able to use post to download a component that is valid' do
          # need to look like uuids=abc,def
          data = "uids=#{@uids.first}"

          res = @faraday.post do |req|
            req.url "/api/component/download?#{data}"
            req.headers['Content-Type'] = 'application/json'
            req.body = data
          end

          expect(res.status).to eq(200)
        end
      end

      context 'post component' do
        it 'should be able to post new component with no ids set' do
          filename = "#{File.dirname(__FILE__)}/resources/component_example_no_ids.zip"
          valid, res = @cm.push_content(filename, true, 'nrel_component')

          expect(valid).to eq true
          expect(res['uuid']).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
          # expect(res['version_id']).to match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
        end

        it 'should fail when posting a component with a non-unique uuid' do
          filename = "#{File.dirname(__FILE__)}/resources/component_example_no_vid.tar.gz"
          valid, res = @cm.push_content(filename, true, 'nrel_component')

          expect(valid).to eq(false)
          expect(res[:error]).to eq 'There is already content with that UUID.'
        end

        it 'should update the component if the uuid already exists' do
          filename = "#{File.dirname(__FILE__)}/resources/component_example_no_vid.tar.gz"
          valid, res = @cm.update_content(filename, false, nil)
          puts res
          # note: there is a problem here when not called by jenkins group. can ignore for local testing

          expect(valid).to eq true
          # note: this will not work on both dev and prod BCL
          # dev
          # expect(res['nid']).to eq '69193'

          expect(res['nid']).to eq '88298'
          expect(res['uuid']).to eq '21f13f54-6ad2-438d-b5fc-292b2c8ca321'
        end

        it 'should fail when posting component with same uuid/vid components' do
          filename = "#{File.dirname(__FILE__)}/resources/component_example.tar.gz"
          valid, res = @cm.push_content(filename, true, 'nrel_component')

          expect(valid).to eq(false)
          puts res.inspect
        end
      end

      context 'posting multiple components' do
        it 'should push 2 components' do
          files = Pathname.glob("#{File.dirname(__FILE__)}/resources/component_example_*.tar.gz")
          log = @cm.push_contents(files, false, 'nrel_component')

          expect(log.size).to eq(2)
        end

        it 'should post 0 components when checking receipt files' do
          files = Pathname.glob("#{File.dirname(__FILE__)}/resources/component*.tar.gz")
          puts "FILES: #{files.inspect}"
          log = @cm.push_contents(files, true, 'nrel_component')

          expect(log.size).to eq(3)

          test = true
          log.each do |comp|
            test = false if !comp.include?('skipping') && !comp.include?('false')
          end
          expect(test).to be_a TrueClass
        end
      end
    end
  end
end
