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
