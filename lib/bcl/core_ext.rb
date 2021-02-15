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

class String
  def to_underscore
    gsub('OpenStudio', 'Openstudio')
      .gsub('EnergyPlus', 'Energyplus')
      .gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .tr(' ', '_')
      .squeeze('_')
      .downcase
  end

  def to_bool
    return true if self == true || self =~ /(true|t|yes|y|1)$/i
    return false if self == false || self =~ /(false|f|no|n|0)$/i

    raise "invalid value for Boolean: '#{self}'"
  end

  # simple method to create titles -- very custom to catch known inflections
  def titleize
    arr = ['a', 'an', 'the', 'by', 'to']
    upcase_arr = ['DX', 'EDA', 'AEDG', 'LPD', 'COP']
    r = tr('_', ' ').gsub(/\w+/) do |match|
      match_result = match
      if upcase_arr.include?(match.upcase)
        match_result = upcase_arr[upcase_arr.index(match.upcase)]
      elsif arr.include?(match)
        match_result = match
      else
        match_result = match.capitalize
      end
      match_result
    end

    r
  end
end
