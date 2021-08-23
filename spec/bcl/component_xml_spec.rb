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

describe BCL::Component do
  context 'create new component' do
    before(:all) do
      @savepath = './spec/bcl/output'
      @comp = BCL::Component.new(@savepath)
    end

    it 'should add a file' do
      @comp.add_file('abc', '1.2', 'def', 'ghi', 'energyplus', 'usage', 'checksum')

      expect(@comp.files.size).to eq 1
    end

    it 'should save the component' do
      FileUtils.rm("#{@savepath}/component.xml") if File.exist?("#{@savepath}/component.xml")
      @comp.save_component_xml

      expect(File.exist?("#{@savepath}/component.xml")).to eq(true)
    end
  end

  context 'parsing XML' do
    it 'should find uuid, version_id from XML file' do
      uuid = nil
      vid = nil

      file = "#{File.dirname(__FILE__)}/resources/measure.xml"

      # extract uuid  and vid
      bcl = BCL::ComponentMethods.new
      uuid, vid = bcl.uuid_vid_from_xml(file)

      puts "UUID: #{uuid}, VID: #{vid}"

      expect(uuid).not_to be_nil
      expect(vid).not_to be_nil
    end

    it 'should find uuid, version_id from tarball' do
      uuid = nil
      vid = nil

      file = "#{File.dirname(__FILE__)}/resources/measure_original.tar.gz"

      # extract uuid  and vid
      bcl = BCL::ComponentMethods.new
      uuid, vid = bcl.uuid_vid_from_tarball(file)

      puts "UUID: #{uuid}, VID: #{vid}"

      expect(uuid).not_to be_nil
      expect(vid).not_to be_nil
    end
  end

  context 'complex component' do
    before(:all) do
      @savepath = './spec/bcl/output'
      @component_name = 'test_component'
      @comp = BCL::Component.new(@savepath)
    end

    it 'should add data' do
      @comp.name = @component_name
      @comp.description = 'A test component'
      @comp.fidelity_level = '0'
      @comp.source_manufacturer = 'No one'
      @comp.source_url = '/dev/null/'

      @comp.add_provenance('author', 'datetime', 'comment')
      @comp.add_tag('testing')
      @comp.add_attribute('is_testing', true, '')
      @comp.add_attribute('size', 1.0, 'ft')
      @comp.add_attribute('roughness', 'very', '')
    end

    it 'should resolve paths' do
      expect(@comp.resolve_path).to eq("#{@savepath}/#{@component_name}")
      @comp.save_component_xml
      # FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
      # assert((not File.exists?(component_dir)))
      # component.save_tar_gz
      # assert(File.exists?(component_dir))
      # assert(File.exists?(component_dir + "/" + component_name + "/component.xml"))
      # assert(File.exists?(component_dir + "/" + component_name + "/" + component_name + ".tar.gz"))
    end
  end
end
