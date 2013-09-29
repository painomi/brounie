# -*- coding: UTF-8 -*-
$stdout.set_encoding('Windows-31J')

require '../lib/brounie/dice.rb'

class DiceRoll
	attr_reader :said, :fix, :dice
end

describe DiceRoll do
	context '解釈できない文字列には nilを返す' do
		it '数字やダイス表現が含まれない文字列' do
			lambda{DiceRoll::parse('こんにちは。')}.should raise_error
		end
		
		it '数字だけが含まれる文字列' do
			lambda{DiceRoll::parse('5+5-10')}.should raise_error
		end
	end
	
	context 'D6 x n のダイスロールができる' do
		before do
			srand(0)
		end
		
		it 'ダイスロールだけの文字列' do
			s= '2D+4'
			d=DiceRoll::parse(s)
			expect(d).to be_an_instance_of(DiceRoll)
			r= d.roll
			expect(r).to include('4+[6][5]')
			expect(r).to include(s)
		end
		
		it '文字列中にダイスロールが混じっているケース' do
			s= '通常で2d、マスタリーで1d、武器の攻撃力が11でスキルで+4です'
			d=DiceRoll::parse(s)
			expect(d).to be_an_instance_of(DiceRoll)
			r= d.roll
			expect(r).to include('15+[6][5][1]')
			expect(r).to include(s)
		end
	end
	
	context 'D66 のダイスロールができる' do
		before do
			srand(0)
		end
		
		it 'D66だけ' do
			s= 'D66'
			d=DiceRoll::parse(s)
			expect(d).to be_an_instance_of(DiceRoll)
			r= d.roll
			expect(r).to include('[56]')
			expect(r).to include(s)
		end
	end
end
