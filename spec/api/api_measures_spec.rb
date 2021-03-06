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

    context 'and uploading measures' do
      before :all do
        @cm.login unless @cm.logged_in
      end

      # NOTE: must delete "Test Gem Measure" from BCL first each time this is run
      it 'should upload a measure' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_original.tar.gz"
        puts "Filename: #{filename}"
        valid, res = @cm.push_content(filename, false, 'nrel_measure')
        puts "VALID: #{valid}, RESULTS: #{res.inspect}"
        expect(valid).to eq true
      end

      it 'should update a measure' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_updated.tar.gz"
        valid, res = @cm.update_content(filename, false, nil)
        expect(valid).to eq true
      end

      it 'should fail upload of existing measure (UUID match)' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_error_uuidExists.tar.gz"
        valid, res = @cm.push_content(filename, false, 'nrel_measure')
        expect(valid).to eq false
        expect(res[:error]).to eq 'There is already content with that UUID.'
      end

      it 'should fail update of existing measure with same Version ID (VUUID match)' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_error_versionIdExists.tar.gz"
        valid, res = @cm.update_content(filename, false, nil)
        expect(valid).to eq false
        expect(res[:error]).to eq 'There is already content with that Version ID (VUUID).'
      end

      it 'should fail update with malformed UUID' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_updated.tar.gz"
        expect { @cm.update_content(filename, false, '1234-1234') }.to raise_error 'uuid of 1234-1234 is invalid'
      end

      it 'should fail upload/update with topLevel directory in tar.gz' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_error_topLevelFolder.tar.gz"
        valid, res = @cm.update_content(filename, false, 'ee1ff23a-c8d0-4998-8a5f-abad5969d46b')
        expect(valid).to eq false
        expect(res[:error]).to eq 'No XML file was found at the top level of the archive file.  Check your archive file to ensure you do not have a parent directory at the top level.'
      end

      it 'should fail upload/update with bad attribute in xml' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_error_badAttribute.tar.gz"
        valid, res = @cm.update_content(filename, false, nil)
        expect(valid).to eq false
        expect(res[:error]).to eq 'Your file contains an invalid attribute: Attribute Does Not Exist'
      end

      it 'should fail upload/update when there is an <error> tag in the xml' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_error_errorInXml.tar.gz"
        valid, res = @cm.update_content(filename, false, nil)
        expect(valid).to eq false
        expect(res[:error]).to eq 'Cannot upload content with the \'error\' field set in the XML.'
      end

      it 'should fail upload/update when file described in xml is not in tar.gz' do
        filename = "#{File.dirname(__FILE__)}/resources/measure_error_missingFile.tar.gz"
        valid, res = @cm.update_content(filename, false, nil)
        expect(valid).to eq false
        expect(res[:error]).to eq 'File: test_gem_measure_test.rb could not be found in the archive.'
      end

      it 'should not be able to update a measure that doesn\'t already exist' do
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
        expect(res[:error]).to start_with 'Internal Server Error : An error occurred (0): phar error:'
      end
    end
  end
end
