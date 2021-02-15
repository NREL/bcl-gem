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
