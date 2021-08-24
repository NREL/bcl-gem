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
