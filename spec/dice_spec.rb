# -*- coding: UTF-8 -*-
$stdout.set_encoding('Windows-31J')

require '../lib/brounie/dice.rb'

class DiceRoll
	attr_reader :said, :fix, :dice
end

describe DiceRoll do
	context '解釈できない文字列には nilを返す' do
		it '数字やダイス表現が含まれない文字列' do
			expect(DiceRoll::parse('こんにちは。')).to be_false
		end
		
		it '数字だけが含まれる文字列' do
			expect(DiceRoll::parse('5+5-10')).to be_false
		end
	end
	
	context 'D6 x n のダイスロールができる' do
		before do
			srand(0)
		end
		
		it 'ダイスロールだけの文字列' do
			d=DiceRoll::parse('2D+4')
			expect(d).to be_an_instance_of(DiceRoll)
			r= d.roll
			expect(r).to match(/4\+\[6\]\[5\]/)
			expect(r).to match(/2D\+4/)
		end
		
		it '文字列中にダイスロールが混じっているケース' do
			d=DiceRoll::parse('通常で2d、マスタリーで1d、武器の攻撃力が11でスキルで+4です')
			expect(d).to be_an_instance_of(DiceRoll)
			r= d.roll
			expect(r).to match(/15\+\[6\]\[5\]\[1\]/)
			expect(r).to match(/通常で2d、マスタリーで1d、武器の攻撃力が11でスキルで\+4です/)
		end
	end
	
	context 'D66 のダイスロールができる' do
		before do
			srand(0)
		end
		
		it 'D66だけ' do
			d=DiceRoll::parse('D66')
			expect(d).to be_an_instance_of(DiceRoll)
			r= d.roll
			expect(r).to match(/\[56\]/)
			expect(r).to match(/D66/)
		end
	end
end
