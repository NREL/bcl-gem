require 'spec_helper'

describe BCL::Component do
  before(:all) do
    @savepath = "./spec/bcl/output"
    @comp = BCL::Component.new(@savepath)
  end

  context "create new component" do
    it "should add a file" do
      @comp.add_file("abc", "1.2","def", "ghi", "energyplus", "usage", "checksum")

      @comp.files.size.should == 1
    end

    it "should save the component" do
      FileUtils.rm("#{@savepath}/component.xml") if File.exists?("#{@savepath}/component.xml")
      @comp.save_component_xml()

      File.exists?("#{@savepath}/component.xml").should be_true
    end
  end

end
