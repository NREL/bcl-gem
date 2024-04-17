# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'spec_helper'

describe 'BCL API' do
  context '::Measure' do
    before :all do
      @cm = BCL::ComponentMethods.new
    end

    context 'LEGACY API v2.0 - search measure information (simple search, returns JSON-parsed hash with symbols only)' do
      before :all do
        query = 'hvac.json'
        filter = 'fq[]=bundle:nrel_measure&show_rows=3&api_version=2.0'
        @results = @cm.search(query, filter)
      end

      it 'should return a valid search' do
        # puts "Search results #{@results[:result]}"
        expect(@results[:result].count).to eq(3)
        expect(@results[:result][0][:measure][:name]).to be_a String
      end

      it 'should return three results' do
        expect(@results[:result].count).to eq 3
      end

      it 'should return results in hash with symbols (even when querying in xml)' do
        query = 'hvac.xml'
        filter = 'fq[]=bundle:nrel_measure&show_rows=3&api_version=2.0'
        expect(@results[:result].count).to eq(3)
        expect(@results[:result][0][:measure][:name]).to be_a String
      end
    end
    context 'NEW SYNTAX API - search measure information (simple search, returns JSON-parsed hash with symbols only)' do
      before :all do
        query = 'hvac.json'
        filter = 'fq=bundle:measure&show_rows=3'
        @results = @cm.search(query, filter)
      end

      it 'should return a valid search' do
        # puts "Search results #{@results[:result]}"
        expect(@results[:result].count).to eq(3)
        expect(@results[:result][0][:measure][:name]).to be_a String
      end

      it 'should return three results' do
        expect(@results[:result].count).to eq 3
      end

      it 'should return results in hash with symbols (even when querying in xml)' do
        query = 'hvac.xml'
        filter = 'fq=bundle:measure&show_rows=3'
        expect(@results[:result].count).to eq(3)
        expect(@results[:result][0][:measure][:name]).to be_a String
      end
    end
  end
end
