# -*- coding: UTF-8 -*-
$stdout.set_encoding('Windows-31J')

=begin
BrounieBotの基本構文

[-－](<char_name>.)<command><data>

	要素間は空白文字があってもよい。なくても良い
	<char_name>を省略すると、nickから特定する。特定できない場合はエラー
	<command>は、英語と日本語コマンドの両方を使える(例：roll=判定)
	<command>は、特定できる範囲で省略可能(例：ro=roll)
	<command>は、全角半角、大文字小文字を区別しない
=end

require '../lib/brounie/brounie_bot.rb'
require 'active_support/core_ext'

class String
	def to_irc
		NKF::nkf('-Wjm', self).force_encoding('ASCII-8BIT')
	end
end

class Brounie::Session
	attr_accessor :chars, :ode
	
	def clear_chars
		@chars= [ @chars[0] ]
	end
end

include BrounieBot
describe BrounieBot do
	class NadokaBrounieBot
		include NadokaBot
		
		def send_notice(ch, msg)
		end
	end
	
	before do
		@sess=  Session.instance.session
		@nicks= Session.instance.nicks
		@done=  Session.instance.done
		@undo=  Session.instance.undo
	end
	
	describe NadokaBot do
		before(:all) do
			@bot = NadokaBrounieBot.new
			@bot.bot_initialize
		end
		
		describe '#on_privmsg' do
			it "Commands.parse を呼ぶこと" do
				input= "何かの発言"
				prefix= double('prefix', :nick => 'PL-A')
				msg= NKF::nkf('-Wjm', input).force_encoding('ASCII-8BIT')
				Commands.instance.should_receive(:parse)
				@bot.on_privmsg(prefix, :channel, msg)
			end
			
			context "途中に-(半角)や－(全角)が入ってる発言" do
				let(:input) {"途中に-(半角)や－(全角)が入ってる発言。"}
				it "無視すること。" do
					@bot.should_not_receive(:send_notice)
				end
			end
		end
	end
	
	describe Commands do
		describe '#parse' do
			after do
				prefix= double('prefix', :nick => 'PL-A')
				Commands.instance.parse(prefix, @input)
			end
			
			it "コマンド名をパースして各コマンドの parseを呼ぶこと" do
				Join.should_receive(:parse).with('きゃらA', nil, 'PL-A')
				@input= '-join きゃらA'
			end
			
			it "日本語のコマンド名を認識すること" do
				Join.should_receive(:parse).with('きゃらA', nil, 'PL-A')
				@input= 'ー参加 きゃらA'
			end
			
			it "コマンドの省略系を認識すること" do
				Information.should_receive(:new).with('', nil)
				@nicks.delete('PL-A')
				@input= '-info'
			end
			
			it "「.」区切りでキャラ名を認識すること" do
				Impact.should_receive(:new).with('3', 'きゃらA')
				@input= '-きゃらA.impact 3'
			end
			
			it "「、」区切りでキャラ名を認識すること" do
				Impact.should_receive(:new).with('3', 'きゃらA')
				@input= 'ーきゃらA、イン 3'
			end
			
			it "[id].[command] 形式で、キャラ名を認識すること" do
				Impact.should_receive(:new).with('3', 'きゃらA')
				id= @sess.put_in('きゃらA') unless id= @sess.char_idx('きゃらA')
				@input= '-'+ id.to_s+ '.impact 3'
			end
		end
	end
	
	shared_context 'PC 2人とNPC 2人' do
		before do
			Session.instance.session.clear_chars
			Session.instance.nicks = Hash.new
			Session.instance.done = []
			Session.instance.undo = []
			pl_1= double('prefix', :nick => 'PL-1')
			Commands.instance.parse(pl_1,  "-j きゃらA").do
			pl_2= double('prefix', :nick => 'PL-2')
			Commands.instance.parse(pl_2,  "-j きゃらB").do
			gm= double('prefix', :nick => 'GM')
			Commands.instance.parse(gm,  "-j きゃらC").do
			Commands.instance.parse(gm,  "-j きゃらD").do
		end
		after do
			Session.instance.session.clear_chars
			Session.instance.nicks = Hash.new
			Session.instance.done = []
			Session.instance.undo = []
		end
	end
	
	shared_examples_for "正しく転送されること" do
		it do
			@params.each do | input, send |
				method= @command.name.demodulize.underscore
				@class_r.should_receive(method).with(*send)
				com= @command.new(*input)
				com.do_main
			end
		end
	end
	
	shared_examples_for "undoで元に戻ること" do
		it do
			@params.each do | input, send |
				before= @class_r.to_s
				command= @command.new(*input)
				command.do_main
				after= command.undo
				after.should == before
			end
		end
	end
	
	#--- Session ---
	describe Information do
		before do
			@command  = Information
			@class_r  = @sess
			@params =[
				[ ['なんでも良い', 'きゃらA'], [] ],
				[ ['なんでも良い', nil], [] ],
			]
		end
		it_behaves_like "正しく転送されること"
		
		describe 'キャラの表示順は先制が高い順' do
			include_context 'PC 2人とNPC 2人'
			it do
				Initiative.new('3', 'きゃらA').do_main
				Initiative.new('2', 'きゃらB').do_main
				Initiative.new('5', 'きゃらC').do_main
				Initiative.new('4', 'きゃらD').do_main
				message= Information.new('', 'きゃらC').do_main
				message.should =~ /きゃらC.*きゃらD.*きゃらA.*きゃらB/m
			end
		end
	end
	
	describe Save, Load do
		include_context 'PC 2人とNPC 2人'
		
		it 'ファイル名を指定して保存' do
			sess=  Session.instance.session
			nicks= Session.instance.nicks
			done=  Session.instance.done
			undo=  Session.instance.undo
			before= [sess.to_s, nicks.dup, done.dup, undo.dup]
			Save.new('from_spec', 'GM').do_main
			Join.parse('きゃらE', nil, 'GM').do_main
			Load.new('from_spec', 'GM').do_main
			sess=  Session.instance.session
			nicks= Session.instance.nicks
			done=  Session.instance.done
			undo=  Session.instance.undo
			[sess.to_s, nicks, done, undo].should == before
		end
		
		it 'ファイル名を指定しないと日付＋時間で保存される'
	end
	
	describe Join do
		before do
			Session.instance.session.clear_chars
			Session.instance.nicks = Hash.new
		end
		
		it "キャラ名がない時は例外" do
			expect { 
				Join.parse('', nil, 'PL-1').do_main 
			}.to raise_error(InterpreterError)
		end
		
		context "nickに対して最初のキャラが参加した場合" do
			before do
				Join.parse('きゃらA', nil, 'PL-1').do_main
			end
			
			it "キャラが追加されること" do
				@sess.char_idx('きゃらA').should be_a_kind_of(Integer)
			end
			
			it "nickにキャラが紐づくこと" do
				char_idx= @sess.char_idx('きゃらA')
				nicks_char= Session.instance.nicks['PL-1']
				nicks_char.should == char_idx
			end
		end
		
		context "nickに対して紐づいているキャラとは別キャラが参加した場合" do
			before do
				idx= @sess.put_in('きゃらA')
				@nicks['PL-1']= idx
				Join.parse('きゃらB', nil, 'PL-1').do_main
			end
			
			it "キャラが追加されること" do
				@sess.char_idx('きゃらB').should be_a_kind_of(Integer)
			end
			
			it "nickに紐づくキャラは変わらないこと" do
				@nicks['PL-A']= @sess.char_idx('きゃらA')
			end
		end
		
		after do
			Session.instance.session.clear_chars
			Session.instance.nicks = Hash.new
		end
	end
	
	describe Exit do
		before do
			@command  = Exit
			@sess.put_in('きゃらA') unless idx= @sess.char_idx('きゃらA')
			@class_r  = @sess
			@params =[
				[ ['なんでも良い', 'きゃらA'], ['きゃらA'] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	#--- Hap ---
	describe Enable do
		before do
			@command  = Enable
			@class_r  = @sess.haps['昼下がり']
			@sess.haps['昼下がり'].disable
			@params =[
				[ ['昼下がり', 'きゃらA'], [] ],
			]
		end
		it_behaves_like "正しく転送されること"
		pending('[不具合] undoがうまくいってない') do
			it_behaves_like "undoで元に戻ること"
		end
	end
	
	describe Disable do
		before do
			@command  = Disable
			@class_r  = @sess.haps['春']
			@sess.haps['春'].enable
			@params =[
				[ ['春', 'きゃらA'], [] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	#--- Ode ---
	describe Sway do
		before do
			@sess.ode = Brounie::Ode.new
			@command  = Sway
			@class_r  = @sess.ode
			@sess.ode.sway(:CT, 3)
			@sess.ode.sway(:RM, 3)
			@sess.ode.sway(:LN, 3)
			@params =[
				[ ['HF',      'きゃらA'], [:HF, 1] ],
				[ ['hf 3',    'きゃらA'], [:HF, 3] ],
				[ ['HF 2 CT', 'きゃらA'], [:HF, 2, :CT] ],
			]
		end
		it_behaves_like "正しく転送されること"
	end
	
	describe Conclusion do
		before do
			@command  = Conclusion
			@class_r  = @sess.ode
			@params =[
				[ ['なんでも良い', 'きゃらA'], [] ],
				[ ['なんでも良い', nil], [] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	#--- Phase ---
	describe Phase do
	end
	
	describe CutIn do
		before do
			@command  = CutIn
			@class_r  = @sess.phase
			@params =[
				[ ['なんでも良い', 'きゃらA'], ['きゃらA'] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	describe End do
		before do
			@command  = End
			@class_r  = @sess.phase
			@params =[
				[ ['なんでも良い', 'きゃらA'], [] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	describe Next do
		before do
			@command  = Next
			@class_r  = @sess.phase
			@params =[
				[ ['なんでも良い', 'きゃらA'], [] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	#--- Character ---
	describe Initiative do
		before do
			@command  = Initiative
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@params =[
				[ ['5 後ろに何か書いてあっても良い', 'きゃらA'], [5] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	describe Hap do
		before do
			@command  = Hap
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			@sess.haps['秋'].enable
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@params =[
				[ ['秋', 'きゃらA'], ['秋'] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	describe Say do
		before do
			@command  = Say
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@params =[
				[ ['純真で素振り 3D+6', 'きゃらA'], ['純真で素振り 3D+6'] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	describe Roll do
		before do
			@command  = Roll
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@params =[
				[ ['なんでも良い', 'きゃらA'], [nil] ],
				[ ['1 なんでも良い', 'きゃらA'], [1] ],
			]
		end
		it_behaves_like "正しく転送されること"
	end
	
	describe Result do
		before do
			@command  = Result
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@params =[
				[ ['なんでも良い', 'きゃらA'], [] ],
			]
		end
		it_behaves_like "正しく転送されること"
	end
	
	describe Impact do
		before do
			@command  = Impact
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@params =[
				[ ['5 後ろに何か書いてあっても良い', 'きゃらA'], [5] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	describe Open do
		before do
			@command  = Open
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@class_r.impact(5)
			@params =[
				[ ['4 後ろに何か書いてあっても良い', 'きゃらA'], [4] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	describe Delete do
		before do
			@command  = Delete
			@sess.exit('きゃらA') if @sess.char_idx('きゃらA')
			id= @sess.put_in('きゃらA')
			@class_r  = @sess.chars[id]
			@class_r.impact(5)
			@class_r.open(4)
			@params =[
				[ ['3 後ろに何か書いてあっても良い', 'きゃらA'], [3] ],
			]
		end
		it_behaves_like "正しく転送されること"
		it_behaves_like "undoで元に戻ること"
	end
	
	#--- bot ---
	describe Undo do
		include_context 'PC 2人とNPC 2人'
		
		it do
			sess=  Session.instance.session
			nicks= Session.instance.nicks
			before= [sess.to_s, nicks.dup]

			Enable.new('秋', nil).do_main
			Hap.new('秋', 'きゃらA').do_main
			Hap.new('秋', 'きゃらB').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			
			sess=  Session.instance.session
			nicks= Session.instance.nicks
			[sess.to_s, nicks].should == before
		end
	end
	
	describe Redo do
		include_context 'PC 2人とNPC 2人'
		
		it do
			pending 'Redoの時にダイス目が変わることに対処できていない'
			Enable.new('秋', nil).do_main
			#2 4 吸い込まれるような青い空が高く広く広がっています。(ハートフル+1)
			Hap.new('秋', 'きゃらA').do_main
			#4 2 見事な夕焼けが辺り一面を染め上げます（ロマンティック+1)			
			Hap.new('秋', 'きゃらB').do_main
			
			sess=  Session.instance.session
			nicks= Session.instance.nicks
			after= [sess.to_s, nicks.dup]
			
			Undo.new('なんでも良い', 'きゃらC').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			Undo.new('なんでも良い', 'きゃらC').do_main
			
			sess=  Session.instance.session
			nicks= Session.instance.nicks
			[sess.to_s, nicks].should == after
		end
	end
	
	describe Help do
		it 'ヘルプ（コマンド指定なし）' do
			msg= Help.new('', 'きゃらC').do_main
			msg.should =~ /[-ー－]/
		end
		
		it 'ヘルプ（コマンド一覧）' do
			msg= Help.new('all', 'きゃらC').do_main
			msg.should =~ /join/
			msg.should =~ /information/
		end
		
		it 'ヘルプ（特定コマンド）' do
			msg= Help.new('joi', 'きゃらC').do_main
			msg.should =~ /join/
			msg.should =~ /参加/
		end
	end
	
	context "指摘・要望" do
		it "[要望] 行動終了かどうかの識別"
		it "[不具合] sayの前にrollすると変なことになる"
		it "[不具合] n個目のダイスの振り直しができない"
		it "[要望]「世界の部品・倦怠の日々」対応"
		it "[要望] Undo / Redo 後に判りやすく表示する"
		it "[要望] 宣言内容を受け付けたメッセージ"
		it "[不具合] 全角 2文字のキャラ名がリストでずれる"
	end
end
