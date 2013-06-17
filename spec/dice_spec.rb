# -*- coding: UTF-8 -*-
$stdout.set_encoding('Windows-31J')

require '../lib/brounie/dice.rb'

class DiceRoll
	attr_reader :said, :fix, :dice
end

describe DiceRoll do
	subject { DiceRoll::parse(string) }

	context '解釈できない文字列には nilを返す' do
		context '数字やダイス表現が含まれない文字列' do
			let(:string) { 'こんにちは。' }
			it { expect(subject).to be_nil }
		end
		
		context '数字だけが含まれる文字列' do
			let(:string) { '5+5-10' }
			it { expect(subject).to be_nil }
		end
	end

	describe 'ダイスがロール出来る' do
		before { srand(0) }
		shared_examples_for 'dice roll' do
			it { expect(subject).to be_an_instance_of(DiceRoll) }
			its(:roll) { expect(subject).to include(result) }
			its(:roll) { expect(subject).to include(string) }
		end

		context 'D6 x n のダイス' do
			context 'ダイスロールだけの文字列' do
				let(:string) { '2D+4' }
				let(:result) { '4+[6][5]' }
				it_should_behave_like 'dice roll'
			end
			
			context '文字列中にダイスロールが混じっているケース' do
				let(:string) { '通常で2d、マスタリーで1d、武器の攻撃力が11でスキルで+4です' }
				let(:result) { '15+[6][5][1]' }
				it_should_behave_like 'dice roll'
			end
		end
		
		context 'D66 のダイス' do
			context 'D66だけ' do
				let(:string) { 'D66' }
				let(:result) { '[56]' }
				it_should_behave_like 'dice roll'
			end
		end
	end
end
