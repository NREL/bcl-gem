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

describe String do
  context 'underscores' do
    it 'should convert strings' do
      expect('OpenStudio'.to_underscore).to eq 'openstudio'
      expect('OpenStudioResults'.to_underscore).to eq 'openstudio_results'
      expect('Results_Are_NotImportant'.to_underscore).to eq 'results_are_not_important'
      expect('Pointless'.to_underscore).to eq 'pointless'
      expect('already_downcased_openstudio'.to_underscore).to eq 'already_downcased_openstudio'
      expect('EnergyPlus_Results'.to_underscore).to eq 'energyplus_results'
      expect('down spaced'.to_underscore).to eq 'down_spaced'
      expect('down     spaced'.to_underscore).to eq 'down_spaced'
      expect('down   ___ spaced'.to_underscore).to eq 'down_spaced'
      expect('down ()  ___ spaced'.to_underscore).to eq 'down_()_spaced'
      expect('123 _ _ _ OpenStudio ___ 456'.to_underscore).to eq '123_openstudio_456'
      expect('OPENSTUDIO'.to_underscore).to eq 'openstudio'
    end
  end

  context 'booleans' do
    it 'should convert boolean strings' do
      ['true', 't', 'yes', 'y', '1'].each do |s|
        expect(s.to_bool).to eq true
      end

      ['false', 'f', 'no', 'n', '0'].each do |s|
        expect(s.to_bool).to eq false
      end
    end
  end
end
