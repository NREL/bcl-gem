require 'spec_helper'

describe BCL::Component do

  before(:all) do
    @comp = BCL::Component.new('./spec/bcl')
    @comp.add_attribute('elev', '5.5', '')
    @comp.add_attribute('elev_typed', 5.5, '')
    @comp.add_attribute('wmo', '1234123412341234123412341234123412341234', '')
    @comp.add_attribute('wmo_typed', 1_234_123_412_341_234_123_412_341_234_123_412_341_234, '')
    @comp.add_attribute('wmo_small', '1234', '')
  end

  context 'after component initializes' do
    it 'should have some attributes' do
      @comp.attributes.size.should eql(5)
    end

    it 'should have datatype of floats' do
      @comp.get_attribute('elev').datatype.should eql('float')
    end

    it 'should have datatype of float if passed as float' do
      @comp.get_attribute('elev_typed').datatype.should eql('float')
    end

    it 'should have datatype of int' do
      @comp.get_attribute('wmo').datatype.should eql('int')
      @comp.get_attribute('wmo_typed').datatype.should eql('int')
      @comp.get_attribute('wmo_small').datatype.should eql('int')
    end

    it 'should title case' do
      @comp.tc('ab cd ef').should eql('Ab Cd Ef')
    end
  end

end
