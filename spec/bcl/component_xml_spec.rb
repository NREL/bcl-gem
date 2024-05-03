# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
