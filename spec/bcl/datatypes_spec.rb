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
      expect(@comp.attributes.size).to eq 5
    end

    it 'should have datatype of floats' do
      expect(@comp.get_attribute('elev').datatype).to eq 'float'
    end

    it 'should have datatype of float if passed as float' do
      expect(@comp.get_attribute('elev_typed').datatype).to eq 'float'
    end

    it 'should have datatype of int' do
      expect(@comp.get_attribute('wmo').datatype).to eq 'int'
      expect(@comp.get_attribute('wmo_typed').datatype).to eq 'int'
      expect(@comp.get_attribute('wmo_small').datatype).to eq 'int'
    end

    it 'should title case' do
      expect(@comp.tc('ab cd ef')).to eq 'Ab Cd Ef'
    end
  end

end
