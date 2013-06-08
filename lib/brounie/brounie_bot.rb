# -*- coding: UTF-8 -*-
$stdout.set_encoding('Windows-31J')

require 'singleton'
require 'yaml'
require 'active_support/core_ext'
require '../lib/brounie.rb'

module Brounie
	
end

module BrounieBot
	class InterpreterError < StandardError; end
	
	module NadokaBot
		def bot_initialize
		end
		
		def on_privmsg(prefix, ch, msg)
			msg= NKF::nkf('-wxm0Z0', msg).force_encoding('UTF-8')
			if command= Commands.instance.parse(prefix, msg)
				message= command.do
			elsif dice_roll= DiceRoll::parse(msg)
				message= dice_roll.roll
			else
				return
			end
			message= NKF::nkf('-wm', message).force_encoding('ASCII-8BIT')
			message.each_line do |line|
				msg= line.strip
				send_notice(ch, msg)
			end
		end
	end
	
	class Session
		include Singleton
		
		def initialize
			@session= Brounie::Session.load('default.yaml')
			@nicks= Hash.new
			@done= []
			@undo= []
		end
		attr_accessor :session, :nicks, :done, :undo
		
		def self.save(filename)
			filename.gsub!(/[\\\/\:\*\?\"\<\>\|]/,'')
			Session.instance.session.save(filename+ '.brs')
			fn= DefaultSaveDir+ '/'+ filename+ '.brb'
			File::open(fn, 'w') do |f|
				f.puts YAML.dump([
					Session.instance.nicks, 
					Session.instance.done, 
					Session.instance.undo
				])
			end
			filename
		end
		
		def self.load(filename)
			filename.gsub!(/[\\\/\:\*\?\"\<\>\|]/,'')
			Session.instance.session= Brounie::Session.load(filename+ '.brs')
			fn= DefaultSaveDir+ '/'+ filename+ '.brb'
			File::open(fn) do |f|
				temp= YAML.load(f.read)
				Session.instance.nicks= temp[0]
				Session.instance.done= temp[1] 
				Session.instance.undo= temp[2]
			end
			filename
		end
	end
	
	class Commands
		include Singleton
		
		def initialize
			@short= make_short
			@all  = make_all
			@help = make_help
		end
		attr_reader :short, :all, :help
		
		def parse(prefix, msg)
			return nil unless msg=~ /\A[-－ー](.*)\z/
			msg= $1.strip
			
			command= nil
			char= nil
			nick= prefix.nick
			nicks= Session.instance.nicks
			sess= Session.instance.session
			
			if msg =~ /\A(.+)[\.、](.+\z)/ then
				char= $1.strip
				if char.to_i.to_s == char and sess.chars[char.to_i]
					char = sess.chars[char.to_i].name
				end
				msg= $2.strip
			end
			
			@short.each do |short, com|
				next unless msg =~ /\A#{short}(.*)\z/i
				command= com
				msg = $1.strip
				break
			end
			
			case 
			when command== nil
				raise BrounieBot::InterpreterError, 
				      "コマンドとして解釈できませんでした\n入力:"+ msg
			when command== Join
				command.parse(msg, char, nick)
			else
				unless char
					id= nicks[nick]
					char= sess.chars[id].name if id
				end
				command.new(msg, char)
			end
		end
		
		def make_short
			list= Command.command_classes
			
			temp= Array.new
			list.each do |com_class|
				com= com_class.name.demodulize.underscore
				1.upto(com.size){|n| temp << [com[0,n], com_class]}
				jp= eval(com_class.name+'::JP')
				1.upto(jp.size){|n| temp << [jp[0,n], com_class]}
			end
			dup= Array.new
			temp.each do |short, com_class|
				dup << short if temp.select{|s, c| s==short}.size > 1
			end
			temp.delete_if{|short, com_class| dup.include?(short)}
			temp.sort_by{|short, com_class| short.size}.reverse
		end
		
		def make_all
			a= @short.map{|s, c| [s, c.name.demodulize.underscore]}
			a= a.group_by{|s, c| c }
			all= Hash.new
			a.each do |name, shorts|
				shorts.map!{|s| s[0]}
				sh= shorts.group_by{|s| s.size== s.bytesize}
				en = sh[true].max + '('+ sh[true].min+ ')'
				jp = sh[false].max+ '('+ sh[false].min+ ')'
				all[name]= en+ ' / '+ jp
			end
			all
		end
		
		def make_help
			a= @short.map do |s, c| 
				help= @all[c.name.demodulize.underscore]
				help+= "\n"+ eval(c.name+'::HELP')
				[s, help]
			end
			Hash[*a.flatten(1)]
		end
	end
	
	class Command
		def initialize(msg, char)
			@msg= msg.strip
			@char_id= Session.instance.session.char_idx(char) if char
			@reciever
			@params= []
			@before
			parse_message
		end
		
		def self.inherited(subclass)
			@command_classes ||= []
			@command_classes.push(subclass)
		end
		
		def self.command_classes
			@command_classes
		end
		
		def parse_message
		end
		
		def parse_string
			@msg =~ /\A(.*)\s?/
			@params.push($1)
			@msg = $'
		end
		
		def parse_integer
			@msg =~ /\A[^\d]*(\d{1,2})/
			@params.push($1 ? $1.to_i : nil)
			@msg = $'
		end
		
		def parse_ode_label
			ode_labels= Brounie::OdeLabels.keys.map{|l| l.to_s}.join('|')
			@msg =~ /\A\s*(#{ode_labels})/i
			@params.push($1.upcase.intern) if $1
			@msg= $'
		end
		
		def char_required
			raise InterpreterError, 'キャラを指定してください。' unless @char_id
		end
		
		def params_push_char
			@params.push(Session.instance.session.chars[@char_id].name)
		end
		
		def do
			begin
				message= do_main
			rescue InterpreterError, Brounie::MisplayError
				message= ($!.class.to_s)+ ':'+ $!.message
			rescue
				message= ($!.class.to_s)+ ':'+ ($!.message) #+ "\n"+
#				         $!.backtrace.join("\n")
			end
			message
		end
		
		def do_main
			@before= @reciever.state
			method= self.class.name.demodulize.underscore
			@reciever.send(method, *@params)
			Session.instance.done.push(self)
			Session.instance.undo= []
			@reciever.to_s
		end
		
		def undo
			@reciever.state= @before
			@reciever.to_s
		end
	end
	
	#--- Session ---
	class Information < Command
		JP= '情報'
		HELP= 
			"キャラ、オーデ、出来事表の情報を表示します。\n"+
			"例「-infomation」"
		def do_main
			Session.instance.session.information
		end
		undef :undo
	end
	
	class Save < Command
		JP= '保存'
		HELP= 
			"セッション情報を保存します。\n"+
			"例「-save ファイル名」"
		def do_main
			parse_string
			"保存しました:"+ Session.save(*@params)
		end
		undef :undo
	end
	
	class Load < Command
		JP= '読み込む'
		HELP= 
			"セッション情報を読み込みます。\n"+
			"例「-load ファイル名」"
		def do_main
			parse_string
			"読み込みました:"+ Session.load(*@params)
		end
		undef :undo
	end
	
	class Join < Command
		JP= '参加'
		HELP=
			"セッションにキャラクターを参加させます。\n"+
			"例「-うに.join」「-joinうに」"
		def initialize(char, nick)
			@char= char
			@nick= nick
		end
		
		def self.parse(msg, char, nick)
			msg.strip!
			msg= nil if msg == ''
			char= msg unless char
			nick=nil if Session.instance.nicks[nick]
			self.new(char, nick)
		end
		
		def do_main
			raise InterpreterError, 'キャラ名を指定してください。' unless @char
			id= Session.instance.session.put_in(@char)
			if @nick
				Session.instance.nicks[@nick]= id
				sprintf("PL:%sさんのPC「%s」が参加しました。\n", @nick, @char)
			else
				sprintf("「%s」が参加しました。\n", @char)
			end
		end
		
		def undo
			Session.instance.exit(@char)
			Session.instance.nicks.delete(@nick) if @nick
			sprintf("「%s」の参加を取り消しました。\n", @char)
		end
	end
	
	class Exit < Command
		JP= '退室'
		HELP= 
			"セッションからキャラクターを退室させます。\n"+
			"例「-exit」「-うに.exit」"
		def parse_message
			char_required
			params_push_char
			@reciever = Session.instance.session
		end
	end
	
	#--- Hap ---
	class Enable < Command
		JP= '有効化'
		HELP=
			"出来事表を有効にします。\n"+
			"例「-enable 春」"
		def parse_message
			parse_string
			hap_str= @params.pop
			hap= Session.instance.session.haps[hap_str]
			raise InterpreterError, '出来事表がありません。' unless hap
			@reciever = hap
		end
	end
	
	class Disable < Command
		JP= '無効化'
		HELP=
			"出来事表を無効にします。\n"+
			"例「-disable 黄昏」"
		def parse_message
			parse_string
			hap_str= @params.pop
			hap= Session.instance.session.haps[hap_str]
			raise InterpreterError, '出来事表がありません。' unless hap
			@reciever = hap
		end
	end
	
	#--- Ode ---
	class Sway < Command
		JP= 'スウェイ'
		HELP=
			"オーデを変化させます。\n"+
			"例「-sway HF」「-sway RM 3」「-sway LN 2 CT」"
		def parse_message
			parse_ode_label
			parse_integer
			@params[1]= 1 unless @params[1]
			parse_ode_label
			@reciever = Session.instance.session.ode
		end
	end
	
	class Conclusion < Command
		JP= 'コンクルージョン'
		HELP=
			"コンクルージョンの処理を行います。\n"+
			"例「-conclusion」"
		def parse_message
			@reciever= Session.instance.session.ode
		end
	end
	
	#--- Phase ---
	class Phase < Command
		JP= 'フェイズ'
		HELP=
			"現在のフェイズを表示します。\n"+
			"例「-phase」"
		def do_main
			Session.instance.session.phase.to_s
		end
		undef :undo
	end
	
	class CutIn < Command
		JP= '割込む'
		HELP=
			"割り込みでキャラのフェイズを発生させます。\n"+
			"例「-cut_in」「-うに.cut_in」"
		def parse_message
			char_required
			params_push_char
			@reciever= Session.instance.session.phase
		end
	end
	
	class End < Command
		JP= '行動終了'
		HELP=
			"手番キャラを行動終了として、次のキャラの手番にします。\n"+
			"例「-end」"
		def parse_message
			@reciever = Session.instance.session.phase
		end
	end
	
	class Next < Command
		JP= '次'
		HELP=
			"手番キャラは傍観して、次のキャラの手番にします。\n"+
			"例「-next」"
		def parse_message
			@reciever = Session.instance.session.phase
		end
	end
	
	#--- Character ---
	class Initiative < Command
		JP= '先制'
		HELP=
			"キャラの行動力を設定します。\n"+
			"例「-うに.initiative 4」「-initiative 5」"
		def parse_message
			parse_integer
			char_required
			@reciever = Session.instance.session.chars[@char_id]
		end
	end
	
	class Hap < Command
		JP= '出来事表'
		HELP=
			"出来事表を振ります。\n"+
			"例「-うに.hap 春」「-hap 春」"
		def parse_message
			parse_string
			char_required
			@reciever = Session.instance.session.chars[@char_id]
		end
		
		def do_main
			@before= [@reciever.state, Session.instance.session.ode.state]
			method= self.class.name.demodulize.underscore
			message= @reciever.send(method, *@params)
			Session.instance.done.push(self)
			Session.instance.undo= []
			message
		end
		
		def undo
			@reciever.state, Session.instance.session.ode.state= @before
			@reciever.to_s
		end
	end
	
	class Say < Command
		JP= '宣言'
		HELP=
			"判定の宣言をします。\n"+
			"例「-say 2D+5+5 純真でアイテム【リボン】を使用」"
		def parse_message
			parse_string
			char_required
			@reciever = Session.instance.session.chars[@char_id]
		end
	end
	
	class Roll < Command
		JP= '判定'
		HELP=
			"宣言の通りにサイコロを振ります。\n"+
			"例「-roll」「-うに.roll」"
		def do_main
			parse_integer
			char_required
			res= Session.instance.session.chars[@char_id].roll(*@params)
			res.result if res
		end
		undef :undo
	end
	
	class Result < Command
		JP= '結果表示'
		HELP=
			"直前の判定結果を表示します。\n"+
			"例「-result」「-うに.result」"
		def do_main
			char_required
			Session.instance.session.chars[@char_id].result
		end
		undef :undo
	end
	
	module Tension
		def parse_message
			parse_integer
			char_required
			@reciever = Session.instance.session.chars[@char_id]
		end
	end
	
	class Impact < Command
		JP= 'インパクト'
		HELP=
			"インパクトを溜めます。\n"+
			"例「-impact 3」「-うに.impact 2」"
		include Tension
	end
	
	class Open < Command
		JP= '開放'
		HELP=
			"テンションを開放します。\n"+
			"例「-open 3」「-うに.open 2」"
		include Tension
	end
	
	class Delete < Command
		JP= '消去'
		HELP=
			"開放済テンションを消去します。\n"+
			"例「-delete 2」「-うに.delete 4」"
		include Tension
	end
	
	#--- bot ---
	class Undo < Command
		JP= '元に戻す'
		HELP=
			"最後に実行したコマンドをキャンセルして元に戻します。\n"+
			"例「-undo」"
		def do_main
			com= Session.instance.done.pop
			if com
				com.undo
				Session.instance.undo.push(com)
			end
		end
		undef :undo
	end
	
	class Redo < Command
		JP= 'やり直す'
		HELP=
			"最後に undoしたコマンドをやり直します。\n"+
			"例「-redo」"
		def do_main
			com= Session.instance.undo.pop
			if com
				com.do_main
				Session.instance.done.push(com)
			end
		end
		undef :undo
	end
	
	class Help < Command
		JP= 'ヘルプ'
		HELP=
			"「-」や「－」からはじめるとコマンドになります。\n"+
			"「-キャラ名.コマンド」のようにキャラ名を指定します。\n"+
			"「-help all」でコマンド一覧を表示します。"
		def do_main
			parse_string
			if @params[0]=='all' or @params[0]=='全部'
				res= Commands.instance.all.values.join("\n")
			elsif @params[0] and @params[0].size>0 then
				res= Commands.instance.help[@params[0]]
				res=
					"コマンドが特定できません。\n"+
					"「-help all」でコマンド一覧を表示します。" unless res
			else
				res= HELP
			end
			res
		end
		undef :undo
	end
	
end

