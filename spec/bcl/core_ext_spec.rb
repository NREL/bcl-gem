require 'spec_helper'

describe String do
  context 'underscores' do
    it 'should convert strings' do
      expect("OpenStudio".to_underscore).to eq 'openstudio'
      expect("OpenStudioResults".to_underscore).to eq 'openstudio_results'
      expect("Results_Are_NotImportant".to_underscore).to eq 'results_are_not_important'
      expect("Pointless".to_underscore).to eq 'pointless'
      expect("already_downcased_openstudio".to_underscore).to eq 'already_downcased_openstudio'
      expect("EnergyPlus_Results".to_underscore).to eq 'energyplus_results'
    end
  end

  context 'booleans' do
    it 'should convert boolean strings' do
      ['true','t','yes','y','1'].each do |s|
        expect(s.to_bool).to eq true
      end

      ['false','f','no','n','0'].each do |s|
        expect(s.to_bool).to eq false
      end
    end
  end
end
