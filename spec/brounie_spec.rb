# -*- coding: UTF-8 -*-
$stdout.set_encoding('Windows-31J')

require 'tempfile'
require '../lib/brounie.rb'

include Brounie

NAMES= %w(きゃら1 きゃら2 きゃら3 きゃら4)
EMP_G= '[----- ----- ----- -----]'
HAP_CATEGORIES= %w(季節 時刻 棲み処 場所)
HAP_NAMES= %w(春 夏 秋 冬 朝 昼 昼下がり 黄昏 夜中 夜更け
             貴族趣味 メルヒェン コロニアル 本棚のある場所 小さな妹の部屋
             素敵なお姉さまの部屋 アトリエ 集まれる場所 精神的瑕疵物件 侘び住まい
             広い場所 廊下 階段 居心地のいい場所 テラス・ベランダ 屋根裏
             台所 浴室 化粧室 地下倉庫 物置 庭園 廃園 廃屋 水のほとり)

class Session
	attr_accessor :chars
end

class Phase
	attr_reader :list, :now, :finished, :cutting_in
end

describe Brounie,"少女展爛会システム" do
	before(:all) do
		@sess = Session.new
	end
	
	context "提示部" do
		context "セッションを新規作成した場合" do
			it "全てのオーデは0" do
				@sess.ode.should be_a_kind_of(Ode)
				@sess.ode.to_s.should == 'オーデ [HF0 RM0 LN0 CT0](0)'
			end
			
			it "出来事表を持っている" do
				@sess.haps.should be_a_kind_of(Haps)
				@sess.haps.each do |hap|
					hap.should be_a_kind_of(Hap)
				end
				@sess.haps.list(:active).should == "いま振れる出来事表はありません"
			end
			
			it "参加しているキャラクタは0人(うにを除く)" do
				@sess.chars.size.should == 1
			end
		end
		
		describe "#put_in 参加" do
			it "キャラクタを追加できる" do
				idx= @sess.put_in(NAMES[0]) unless @sess.char_idx(NAMES[0])
				@sess.chars[idx].should be
			end
			
			it "同じ名前のキャラは追加できない" do
				idx= @sess.put_in(NAMES[0]) unless @sess.char_idx(NAMES[0])
				expect { @sess.put_in(NAMES[0]) }.to raise_error(MisplayError)
			end
		end
		
		describe "#exit 退出" do
			it "キャラが参加していれば退出する" do
				@sess.put_in(NAMES[0]) unless @sess.char_idx(NAMES[0])
				@sess.exit(NAMES[0])
				@sess.char_idx(NAMES[0]).should== nil
			end
			
			it "キャラが参加していなければ例外" do
				@sess.put_in(NAMES[0]) if @sess.char_idx(NAMES[0])
				expect { @sess.exit(NAMES[0]) }.to raise_error(MisplayError)
			end
		end
		
		context "複数のキャラが参加している場合" do
			before do
				NAMES.each_with_index do |name, id|
					idx= @sess.put_in(name) unless @sess.char_idx(name)
				end
			end
			
			it "#list キャラクタリストの表示 (うには見えない)" do
				NAMES.each do |name|
					@sess.list.should be_include(name)
				end
				@sess.list.should_not be_include('うに')
			end
			
			it "#char_idx キャラ名からidを返す" do
				NAMES.each_with_index do |name, id|
					@sess.char_idx(name).should be_a_kind_of(Integer)
				end
				@sess.char_idx('参加していないキャラ').should== nil
				@sess.char_idx('').should== nil
				@sess.char_idx(nil).should== nil
			end
		end
		
		describe "#initiative 先制の設定と表示" do
			before do
				@sess.put_in(NAMES[0]) unless @sess.char_idx(NAMES[0])
				@id= @sess.char_idx(NAMES[0])
			end
			
			it "#initiative 先制の設定" do
				@sess.chars[@id].initiative(4).should =~ /先.*4/
			end
			
			it "#initiative 先制の表示" do
				@sess.chars[@id].initiative(2)
				@sess.chars[@id].initiative().should =~ /先.*2/
			end
		end
		
		describe "保存と開く" do
			it "#save 保存" do
				f= Tempfile.new('brounie')
				@sess.save(f.path).should =~ /#{f.path}/
				f.close(true)
			end
			
			it "#load 開く" do
				f= Tempfile.new('brounie')
				@sess.save(f.path)
				sess= Session::load(f.path)
				sess.should be_a_kind_of(Session)
				f.close(true)
			end
		end
	end
	
	context "展開部" do
		it "情報をまとめて表示できる" do
			@sess.haps['秋'].enable
			@sess.haps['黄昏'].enable
			info = @sess.information
			info.should =~ /出来事/
			info.should =~ /秋/
			info.should =~ /黄昏/
			info.should =~ /オーデ/
			@sess.chars.each do |c|
				next if c.name =~ /うに/
				info.should =~ /#{c.name}/
			end
		end
		
		context "出来事表リストを設定できる" do
			it "一覧表示できる(有効/無効問わず)" do
				haps_list = @sess.haps.list(:all)
				HAP_CATEGORIES.each do |cat|
					haps_list.should =~ /#{cat}/
				end
				HAP_NAMES.each do |name|
					haps_list.should =~ /#{name}/
				end
			end
			
			it "一覧表示できる(有効のみ)" do
				@sess.haps['秋'].disable
				@sess.haps['秋'].enable
				@sess.haps['春'].disable
				haps_list= @sess.haps.list()
				haps_list.should =~ /秋/
				haps_list.should_not =~ /春/
			end
			
			it "一覧表示できる(有効のみ、詳細)" do
				@sess.haps['秋'].enable
				haps_list= @sess.haps.list(:detail)
				haps_list.should =~ /秋/
				haps_list.should =~ /木々が鮮やかな色に染まっています。/
			end
			
			it "有効化/無効化できる" do
				@sess.haps["秋"].enable
				@sess.haps["黄昏"].enable
				active_haps = @sess.haps.list(:active)
				active_haps.should =~ /秋/
				active_haps.should =~ /季節/
				active_haps.should =~ /黄昏/
				active_haps.should =~ /時刻/
				@sess.haps["黄昏"].disable
				@sess.haps["夜更け"].enable
				active_haps = @sess.haps.list(:active)
				active_haps.should_not =~ /黄昏/
				active_haps.should =~ /夜更け/
			end
		end
		
		context "出来事表を振れる" do
			it "出目を指定して出来事を表示できる" do
				@sess.haps["秋"].enable
				@sess.haps["黄昏"].enable
				@sess.haps["秋"].hap(6,6).should == "【枯葉(純従)】(グッズ)がさくさく、さらさらと音を立てます。"
				@sess.haps["黄昏"].hap(3,3).should == "鮮やかな夕焼けになりました。"
			end
			
			it "キャクターが出来事表を振れる"  do
				@sess.haps["昼下がり"].enable
				@sess.chars[0].hap("昼下がり",[1,3]).should be_a_kind_of(String)
				@sess.chars[0].tension.should == 2
			end
			
			it "出来事によってオーデが溜まる" do
				@sess.haps["春"].enable
				rm= @sess.ode.values[:RM]
				@sess.chars[0].hap("春",[1,3])
				@sess.ode.values[:RM].should == rm+1
			end
			
			it "テンションが危険な場合には警告が出る" do
				@sess.haps["春"].enable
				@sess.chars[0].impact(15)
				lambda {@sess.chars[0].hap("春")}.should raise_error(MisplayError)
			end
		end
		
	end
	
	context "再現部(ショウ・アップ)" do
		describe "Phase イニチアティブの管理" do
			before(:all) do
				NAMES.each_with_index do |name, id| 
					@sess.put_in(name) unless @sess.char_idx(name)
				end
				@phase= @sess.phase
			end
			
			it "#line_up 先制が大きい順に並ぶ" do
				@sess.chars[1].initiative(3)
				@sess.chars[2].initiative(5)
				@sess.chars[3].initiative(1)
				@sess.chars[4].initiative(2)
				
				@phase.line_up
				@phase.list.should== [:itv, 2, 1, 4, 3, :ode]
			end
			
			describe "next 次 / end 行動終了" do
				before do
					@phase.line_up
					NAMES.each_with_index do |name, id| 
						@sess.chars[id].initiative(5-id)
					end
				end
				
				it {@phase.to_s.should =~ /【ITV】/}
				it {@phase.next.
				           to_s.should =~ /【きゃら1】/}
				it {@phase.next.next.
				           to_s.should =~ /【きゃら2】/}
				it {@phase.next.next.next.
				           to_s.should =~ /【きゃら3】/}
				it {@phase.next.next.next.next.
				           to_s.should =~ /【きゃら4】/}
				it {@phase.next.next.next.next.next.
				           to_s.should =~ /【ODE】/}
				it {@phase.next.next.next.next.next.next.
				           to_s.should =~ /【ITV】/}
				
				it do
					@phase.end.end.end.end.end
					@phase.finished.should == [1,2,3,4]
				end
			end
			
			describe "cut_in 割込み" do
				before(:all) do
					NAMES.each_with_index do |name, id| 
						@sess.chars[id].initiative(5-id)
					end
					@phase.line_up
					@phase.next # イニシアティブ・フェイズが終了し、きゃら1のフェイズ
					@phase.end  # きゃら1は行動終了し、きゃら2のフェイズ
				end
				
				it {proc{@phase.cut_in(NAMES[0])}.should raise_error(MisplayError)}
				it {@phase.cut_in(NAMES[3]).to_s.should =~ /【きゃら4】/}
				it {@phase.next.to_s.should =~ /【きゃら2】/}
			end
			
			context 'きゃら1が行動終了、きゃら2が傍観した後にきゃら4が割り込んだ場合' do
				before do
					NAMES.each_with_index do |name, id| 
						@sess.chars[id].initiative(5-id)
					end
					@phase.line_up
					@phase.next # イニシアティブ・フェイズが終了し、きゃら1のフェイズ
					@phase.end  # きゃら1は行動終了し、きゃら2のフェイズ
					@phase.next # きゃら2は傍観し、きゃら3のフェイズ
					@phase.cut_in(NAMES[3]) # きゃら4が割り込み
				end
				
				it '割り込んだ時はきゃら4のフェイズ' do
					@phase.to_s.should =~ /【きゃら4】/
				end
				
				it '本来はきゃら3のフェイズであることの表示' do
					@phase.to_s.should =~ /(きゃら3)/
				end
				
				it 'nextするときゃら3のフェイズ' do
					@phase.next.to_s.should =~ /【きゃら3】/
				end
				
				it 'nextしたあと、きゃら2は割り込める' do
					@phase.next
					@phase.cut_in(NAMES[1]).to_s.should =~ /【きゃら2】/
				end
				
				it 'nextしたあと、きゃら4は再び割り込むことはできない' do
					@phase.next
					proc{@phase.cut_in(NAMES[3])}.should raise_error(MisplayError)
				end
				
				it 'next、nextで、オーデ・フェイズとなる' do
					@phase.next.next.to_s.should =~ /【ODE】/
				end
			end
		end
		
		context "判定(アプローチとリプライ)" do
			before(:all) do
				@chg = Challenge.new
			end
		
			it "say 判定を宣言できること" do
				@chg.say('MAD1さんにアプローチ：２Ｄ６ + 3 + 6 + 1')
				@chg.said.should == 'MAD1さんにアプローチ：２Ｄ６ + 3 + 6 + 1'
				@chg.fix.should == 10
				@chg.dice.size.should == 2
				@chg.dice.each do |d|
					d.face.should == 6
				end
				@chg.rolled.should be_false
				
				@chg.say('純真：7+3d')
				@chg.said.should == '純真：7+3d'
				@chg.fix.should == 7
				@chg.dice.size.should == 3
				@chg.dice.each do |d|
					d.face.should == 6
				end
				@chg.rolled.should be_false
			end
			
			it "roll 判定を実行できること" do
				@chg.say('純真：7+3d')
				@chg.roll
				@chg.rolled.should be_true
			end
			
			it "result 判定結果を表示できること" do
				@chg.say('純真：7+3d')
				dice= Array.new(3,Die.new)
				dice= stub(:results).and_return([3, 1, 6])
				dice= stub(:result).and_return(10)
				@chg.dice= dice
				@chg.roll
				@chg.result.should match(/純真：7\+3d \=\> 7\+\[3\]\[1\]\[6\] \= (17)/)
			end
			
			it "roll([n]) 振り直しができること" do
				@chg.say('純真：7+3d')
				@chg.roll
				@chg.roll(2)
				@chg.result.should match(/純真：7\+3d \=\> 7\+\[3\]\[5\]\[6\] \= (21)/)
			end
		end
		
		context "テンションの管理" do
			before(:all) do
				@char1 = Character.new(NAMES[0])
			end
			
			it "impact テンションを溜められること" do
				@char1.impact(7).to_s.should be_include('[///// //--- ----- -----]')
			end
			
			it "open テンションを開放できること" do
				@char1.open(4).to_s.should be_include('[XXXX/ //--- ----- -----]')
			end
			
			it "delete テンションを消去できること" do
				@char1.delete(2).to_s.should be_include('[XX/// ----- ----- -----]')
			end
			
			it "テンションが最大値を超えたら陥落すること" do
				@char1.impact(20)
				@char1.failed?.should be_true
				@char1.to_s.should be_include('【陥落】'+ '[XX/// ///// ///// ///// *****]')
			end
		end
		
		context "オーデの管理" do
			before do
				@ode_new = Ode.new
				@ode_all3 = Ode.new
				@ode_all3.sway(:HF,3).sway(:RM,3).sway(:LN,3).sway(:CT,3).to_s
			end
			
			it "sway([target]) 形式のスウェイ" do
				@ode_new.sway(:HF).to_s.should == "オーデ [HF0>1 RM0 LN0 CT0](1)"
				@ode_new.sway(:RM).to_s.should == "オーデ [HF1 RM0>1 LN0 CT0](2)"
				@ode_new.sway(:LN).to_s.should == "オーデ [HF1 RM1 LN0>1 CT0](3)"
				@ode_new.sway(:CT).to_s.should == "オーデ [HF1 RM1 LN1 CT0>1](4)"
				@ode_new.to_s.should == "オーデ [HF1 RM1 LN1 CT1](4)"
			end
			
			it "sway([target], [count]) 形式のスウェイ" do
				@ode_new.sway(:HF,2).to_s.should == "オーデ [HF0>2 RM0 LN0 CT0](2)"
				@ode_new.sway(:RM,2).to_s.should == "オーデ [HF2 RM0>2 LN0 CT0](4)"
				@ode_new.sway(:LN,2).to_s.should == "オーデ [HF2 RM2 LN0>2 CT0](6)"
				@ode_new.sway(:CT,2).to_s.should == "オーデ [HF2 RM2 LN2 CT0>2](8)"
				@ode_new.to_s.should == "オーデ [HF2 RM2 LN2 CT2](8)"
			end
			
			it "sway([target], [count], [adverse]) 形式のスウェイ" do
				@ode_all3.sway(:HF).to_s
				@ode_all3.sway(:HF, 1, :RM).to_s.should == "オーデ [HF4>5 RM3>2 LN3 CT3](13)"
				@ode_all3.sway(:RM, 1, :LN).to_s.should == "オーデ [HF5 RM2>3 LN3>2 CT3](13)"
				@ode_all3.sway(:LN, 1, :CT).to_s.should == "オーデ [HF5 RM3 LN2>3 CT3>2](13)"
				@ode_all3.sway(:CT, 1, :HF).to_s.should == "オーデ [HF5>4 RM3 LN3 CT2>3](13)"
				@ode_all3.to_s.should == "オーデ [HF4 RM3 LN3 CT3](13)"
			end
			
			it "リーディングの管理" do
				@ode_new.leading.should == nil
				@ode_all3.leading.should == nil
				@ode_all3.sway(:HF)
				@ode_all3.leading.should == :HF
			end
			
			it "コンクルージョンの処理ができること" do
				@ode_all3.sway(:HF).to_s
				@ode_all3.sway(:HF, 3, :CT).to_s.should == "オーデ [HF4>7 RM3 LN3 CT3>0](13)"
				@ode_all3.conclusion.to_s.should == "オーデ [HF7>3 RM3 LN3 CT0](9)"
			end
		end
	end
end

