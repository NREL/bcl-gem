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
