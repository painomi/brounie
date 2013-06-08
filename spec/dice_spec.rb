# -*- coding: Windows-31J -*-

require '../lib/brounie/dice.rb'

class DiceRoll
	attr_reader :said, :fix, :dice
end

describe DiceRoll do
	it '解釈できない文字列には nilを返す' do
		DiceRoll::parse('ロールでない文字列').should== nil
	end
		
	context 'パースしてDiceRollを生成' do
		it 'ダイスロールだけの文字列' do
			srand(0)
			d=DiceRoll::parse('2D+4')
			d.should be_a_kind_of(DiceRoll)
			d.roll.should =~ /4\+\[5\]\[6\]/
		end
	end
end
