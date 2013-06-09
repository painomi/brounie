# -*- coding: Windows-31J -*-

require '../lib/brounie/dice.rb'

class DiceRoll
	attr_reader :said, :fix, :dice
end

describe DiceRoll do
	it '解釈できない文字列には nilを返す' do
		DiceRoll::parse('ロールでない文字列').should== nil
	end
		
	context 'D6 x n のダイスロールができる' do
		before do
			srand(0)
		end
		
		it 'ダイスロールだけの文字列' do
			d=DiceRoll::parse('2D+4')
			d.should be_a_kind_of(DiceRoll)
			d.roll.should =~ /4\+\[5\]\[6\]/
			d.roll.should =~ /2D\+4/
		end
		
		it '文字列中にダイスロールが混じっているケース' do
			d=DiceRoll::parse('通常で2d、マスタリーで1d、武器の攻撃力が11でスキルで+4です')
			d.should be_a_kind_of(DiceRoll)
			d.roll.should =~ /15\+\[5\]\[6\]\[1\]/
			d.roll.should =~ /通常で2d、マスタリーで1d、武器の攻撃力が11でスキルで\+4です/
		end
	end
	
	context 'D66 のダイスロールができる' do
		before do
			srand(0)
		end
		
		it 'D66だけ' do
			d=DiceRoll::parse('D66')
			d.should be_a_kind_of(DiceRoll)
			d.roll.should =~ /\[56\]/
			d.roll.should =~ /D66/
		end
	end
end
