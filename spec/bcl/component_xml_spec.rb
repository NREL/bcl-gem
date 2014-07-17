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

  # TODO CONVERT this to Rspec
  #
  #
  #   def test_osm_and_osc_component
  #     component_dir = File.dirname(__FILE__) + "/output/osm_and_osc_component"
  #     component_name = "test_component"
  #
  #     component = BCL::Component.new(component_dir)
  #     component.name = component_name
  #     component.description = "A test component"
  #     component.fidelity_level = "0"
  #     component.source_manufacturer = "No one"
  #     component.source_url = "/dev/null/"
  #
  #     component.add_provenance("author", "datetime", "comment")
  #     component.add_tag("testing")
  #     component.add_attribute("is_testing", true, "")
  #     component.add_attribute("size", 1.0, "ft")
  #     component.add_attribute("roughness", "very", "")
  #
  #     assert(component.resolve_path == component_dir + "/" + component_name)
  #
  #     FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
  #     assert((not File.exists?(component_dir)))
  #
  #     FileUtils.mkdir(component_dir)
  #     FileUtils.mkdir(component_dir + "/" + component_name)
  #     assert(File.exists?(component_dir))
  #     assert(File.exists?(component_dir + "/" + component_name))
  #
  #     # make a model
  #     osm = OpenStudio::Model::Model.new
  #     version = osm.getVersion
  #     version.versionIdentifier
  #     construction = OpenStudio::Model::Construction.new(osm)
  #     osm.save(OpenStudio::Path.new(component_dir + "/" + component_name + "/component.osm"))
  #     component.add_file("OpenStudio", version.versionIdentifier,
  #                        component_dir + "/" + component_name + "/component.osm",
  #                        "component.osm", "osm")
  #
  #     # make a component
  #     osc = construction.createComponent
  #     osc.save(OpenStudio::Path.new(component_dir + "/" + component_name + "/component.osc"))
  #     component.add_file("OpenStudio", version.versionIdentifier,
  #                        component_dir + "/" + component_name + "/component.osc",
  #                        "component.osc", "osc")
  #
  #     component.save_tar_gz(false)
  #
  #     assert(File.exists?(component_dir + "/" + component_name + "/component.xml"))
  #     assert(File.exists?(component_dir + "/" + component_name + "/" + component_name + ".tar.gz"))
  #   end
  #
  #   def test_gather_components
  #     component_dir = File.dirname(__FILE__) + "/output/gather_components"
  #
  #     FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
  #     assert((not File.exists?(component_dir)))
  #
  #     for i in 0..10 do
  #
  #       component_name = "test_component_#{i}"
  #
  #       component = BCL::Component.new(component_dir)
  #       component.name = component_name
  #       component.description = "A test component"
  #       component.fidelity_level = "0"
  #       component.source_manufacturer = "No one"
  #       component.source_url = "/dev/null/"
  #
  #       component.save_tar_gz
  #     end
  #
  #     assert(File.exists?(component_dir))
  #
  #     File.delete(component_dir + "/gather/components.tar.gz") if File.exists?(component_dir + "/gather/components.tar.gz")
  #     assert((not File.exists?(component_dir + "/gather/components.tar.gz")))
  #
  #     BCL.gather_components(component_dir)
  #
  #     assert(File.exists?(component_dir + "/gather/components.tar.gz"))
  #
  #   end
end
