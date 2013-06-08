# -*- coding: Windows-31J -*-

require '../lib/dice.rb'

describe Roll, '判定' do
	it 'new した時は、2D6の判定とする' do
		r= Roll.new
		r.should be_kind_of(Roll)
		r.to_s.should =~ /\+2D6 =/
	end
	
	context '文字列をパースできること' do
		it '解釈できない文字列には nilを返す' do
			Roll::parse('ロールでない文字列').should== nil
		end
		
		it '解釈できる場合は Rollクラスを返す' do
			Roll::parse('ベースが２Ｄ＋７、アイテムで＋２０、クリティカルで＋２Ｄ').should be_kind_of(Roll)
		end
	end
end
