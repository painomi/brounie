# -*- coding: UTF-8 -*-
$stdout.set_encoding('Windows-31J')

require 'nkf'
require 'yaml'
require 'win32ole'
require '../lib/brounie/dice.rb'

DefaultSaveDir= './data'

class String
	def fit(length)
		if self.bytesize <= length
			return (self+ ' '*(length- self.bytesize))
		else
			res=''
			self.each_char do |c|
				if (res+c).bytesize >= length
					break
				else
					res+=c
				end
			end
			res+='.' if res.bytesize == (length-1)
			res+='…' if res.bytesize == (length-2)
			return res
		end
	end
end

module Excel
end

module Brounie
	OdeLabels = {HF:'ハートフル', RM:'ロマンティック', LN:'ルナティック', CT:'カタストロフ'}
	AbilityLabels = {DMN:'支配', OBD:'従順', CLC:'打算', INC:'純真', EXP:'表現',
	                 GIN:'好意', BIN:'悪意', INI:'先制', PCK:'懐', }
	
	class MisplayError < StandardError; end
	
	class Session
		def initialize
			@haps= Haps.new(HAPS_LIST)
			@ode= Ode.new
			@chars= Array.new
			@phase= Phase.new(self)
			
			put_in('うに', {DMN: 1, OBD: 4, CLC: 5, INC: 3, EXP: 3,
	                      GIN: 2, BIN: 3, INI: 3, PCK: 3, })
		end
		attr_reader  :haps, :ode, :chars, :phase
		
		def state
			@chars.dup
		end
		
		def state=(params)
			@chars= params
		end
		
		def list
			res= "-- キャラ一覧 --\n"
			if @chars.size >1
				uni= @chars.shift
				res << @chars.map{|c| c.to_s}.join("\n")
				@chars.unshift(uni)
			else
				res= '誰もいないようです。'
			end
			res
		end
		
		def information
			res= ''
			res << @ode.to_s+ "\n"
			uni= @chars.shift
			chars = @chars.sort_by{|c| c.ability[:INI]}.reverse
			chars.each do |c|
				id= char_idx(c.name) +1
				ini= c.ability[:INI]
				res += sprintf('%d.(先%d)%s', id, ini, c.to_s)+ "\n"
			end
			@chars.unshift(uni)
			res << @haps.information
		end
		alias :to_s :information
		
		def put_in(name, ability=Hash.new)
			raise MisplayError, name+'は既に参加しています。' if char_idx(name)
			@chars.push(Character.new(name, self, ability))
			@phase.line_up
			return @chars.size-1
		end
		
		def exit(name)
			raise MisplayError, name+'は参加していません。' unless char_idx(name)
			@chars.delete_at(char_idx(name))
			@phase.line_up
			return self
		end
		
		def char_idx(name)
			id=nil
			@chars.each_with_index do |char, i|
				id=i if char.name== name
			end
			id
		end
		
		def roll
			@chars.each{|c| c.roll}
		end
		
		def results
			@chars.map{|c| c.result}.join("\n")
		end
		
		def save(fn)
			dir, file= File::split(fn)
			dir= DefaultSaveDir if dir== '/' or dir== '.'
			fn= dir+ '/'+ file
			File::open(fn, 'w') do |f|
				f.puts YAML.dump(self)
			end
			fn
		end
		
		def self.load(fn)
			dir, file= File::split(fn)
			dir= DefaultSaveDir if dir== '/' or dir== '.'
			fn= dir+ '/'+ file
			f= File::open(fn)
			sess= YAML.load(f.read)
			f.close
			sess
		end
	end
	
	TITLE_ROWS=[1]
	COL_CATEGORY= 'A'
	COL_TITLE= 'B'
	COL_DICE1= 'C'
	COL_DICE2= 'D'
	COL_DESCRIPTION= 'E'
	DICE1_LABEL=['偶','奇']
	class Haps
		def initialize(filename)
			@items= []
			@keys= []
			
			list= Hash.new
			xl= WIN32OLE.new('Excel.Application')
			WIN32OLE.const_load(xl, Excel) unless defined?(Excel::CONSTANTS)
			book= xl.Workbooks.Open(filename)
			sheet= book.Worksheets(1)
			last_row = sheet.UsedRange.End(Excel::XlDown).Row
			1.upto(last_row) do |row|
				next if TITLE_ROWS.include?(row)
				category= sheet.Range(COL_CATEGORY+ row.to_s).value.encode('UTF-8')
				name= sheet.Range(COL_TITLE+ row.to_s).value.encode('UTF-8')
				dice1= DICE1_LABEL.index(sheet.Range(COL_DICE1+ row.to_s).value.encode('UTF-8'))
				dice2= sheet.Range(COL_DICE2+ row.to_s).value.to_i
				description= sheet.Range(COL_DESCRIPTION+ row.to_s).value.encode('UTF-8')
				
				list[name] ||= {category:category, lines:[]}
				list[name][:lines] << [dice1, dice2, description]
			end
			sleep(1)
			book.Close
			xl.Quit
			
			list.each do |name, item|
				category, lines= item[:category], item[:lines]
				if lines.size==12 and
				   lines.all?{|line| [0,1].include?(line[0])} and
				   lines.all?{|line| [1,2,3,4,5,6].include?(line[1])} then
					@items << Hap.new(name, category, lines)
					@keys << name
				end
			end
		end
		
		def [](key_or_index)
			case key_or_index
			when String
				key= key_or_index
				index= @keys.index(key)
				index ? @items[index] : nil
			when Integer
				index= key_or_index
				@items[index]
			end
		end
		
		def each
			@items.each
		end
		
		def information
			actives = @items.select{|h| h.active}
			if actives.empty?
				'出来事表：－'
			else
				'出来事表：'+ actives.map{|h| h.name}.join('/')
			end
		end
		
		def list(select= :active)
			list = "-- 出来事表 --\n"
			return '出来事表はありません' if @items.empty?
			
			case select
			when :all
				@items.each_with_index do |hap, idx|
					flag= hap.active ? '*' : ' '
					list << sprintf("%1s%2d) %s / %s\n", flag, idx+1, hap.category, hap.name)
				end
			when :active
				actives = @items.select{|h| h.active}
				return 'いま振れる出来事表はありません' if actives.empty?
				list = "-- いま振れる出来事表 --\n"
				actives.each_with_index do |hap, idx|
					list << sprintf("%2d) %s / %s\n", idx+1, hap.category, hap.name)
				end
			when :detail
				actives = @items.select{|h| h.active}
				return 'いま振れる出来事表はありません' if actives.empty?
				list = "-- いま振れる出来事表 --\n"
				actives.each_with_index do |hap, idx|
					list << sprintf("%2d) %s / %s\n", idx+1, hap.category, hap.name)
					list << hap.list.map{|l| "\t"+ l}.join("\n")+ "\n"
				end
			end
			list
		end
	end
	
	class Hap
		def initialize(name, category, lines)
			@name = name
			@category =category
			@lines = lines
			@active = false
		end
		attr_reader :name, :category
		attr_accessor :active
		
		def state
			[@active]
		end
		
		def state=(params)
			@active= *params
		end
		
		def to_s
			status= @active ? '有効' : '無効'
			@category+ ' / '+ @name+ ' : '+ status
		end
		
		def list
			@lines.map do |h|
				d1= '偶奇'[h[0]]
				sprintf('[%s][%d] %s', d1, h[1], h[2])
			end
		end
		
		def hap(dice1, dice2)
			hh= @lines.select{|h| !(dice1.odd? ^ h[0].odd?)}
			hh= hh.select{|h| dice2== h[1]}
			if hh.size == 1 then
				return hh[0][2]
			else
				return nil
			end
		end
		
		def enable
			@active = true
			self
		end
		
		def disable
			@active = false
			self
		end
	end
	
	DESCRIPTION = "オーデ "
	class Ode
		def initialize()
			@values = { HF: 0, RM: 0, LN: 0, CT: 0 }
			@previous = Hash.new
		end
		attr_accessor :values, :previous
		
		def state
			[@values.dup, @previous.dup]
		end
		
		def state=(params)
			@values, @previous= *params
		end
		
		def sway(target, count=1, adverse=nil)
			@previous[target]= @values[target]
			raise MisplayError, 'オーデは 7を超えられません。' if @values[target]+ count > 7
			raise MisplayError, 'オーデの合計は 13を超えられません。' if !adverse && self.sum+ count > 13
			raise MisplayError, 'オーデはマイナスにできません。' if adverse && @values[adverse] < count
			raise MisplayError, '特定のオーデだけを減らすことはできません。' if count < 0
			if self.sum== 13 and adverse
				@previous[adverse]= @values[adverse]
				@values[adverse]-=count
			end
			@values[target]+=count
			self
		end
		
		def sum
			@values.values.inject(0){|r, i| r+i}
		end
		
		def conclusion
			concl = @values.key(7)
			if concl
				@previous[concl]= @values[concl]
				@values[concl]= 3
			end
			self
		end
		
		def to_s
			result = Array.new
			@values.each do |label, val|
				if @previous.key?(label) and @previous[label] != val
					result.push label.to_s.upcase+ @previous[label].to_s+ '>'+ val.to_s
				else
					result.push label.to_s.upcase+ val.to_s
				end
			end
			@previous = Hash.new
			
			str = DESCRIPTION
			str += '['+ result.join(' ')+ ']'
			str += '('+ self.sum.to_s+ ')'
			str
		end
		
		def leading
			max_ode = @values.values.max
			max_odes = @values.select{|k,v| v==max_ode}
			if max_odes.size == 1
				max_odes.keys[0]
			else
				nil
			end
		end
	end
	
	class Phase
		def initialize(sess)
			@parent= sess
			@list= []
			self.line_up
			@now= 0
			@finished= []
			@cutting_in= []
		end
		
		def to_s
			res= []
			@list.each_with_index do |phase, num|
				name= ''
				case phase
				when :itv
					name= "ITV"
				when :ode
					name= "ODE"
				else
					name= @parent.chars[phase].name
				end
				if num == @now
					if @cutting_in.empty?
						name= '【'+ name+ '】'
					else
						name= '('+ name+ ')'
					end
				end
				name= '【'+ name+ '】' if @cutting_in.include?(phase)
				res << name
			end
			res.join(' ')
		end
		alias :phase :to_s
		
		def state
			[@list.dup, @now, @finished.dup, @cutting_in.dup]
		end
		
		def state=(params)
			@list, @now, @finished, @cutting_in= *params
		end
		
		def next(act=false)
			if @cutting_in.empty?
				case @list[@now]
				when :itv
					@now+=1
				when :ode
					@now=0
					@finished= []
				else
					@finished.push(@list[@now]) if act
					@now+=1
					@now+=1 while @finished.include?(@list[@now])
				end
			else
				@finished.push(@cutting_in.shift)
			end
			self
		end
		
		def end
			self.next(true)
		end
		
		def cut_in(name)
			id= @parent.char_idx(name)
			raise MisplayError, name+ 'は、セッションに参加しているキャラクターではありません。' unless id
			raise MisplayError, name+ 'は行動済です。' if @finished.include?(id)
			@cutting_in.unshift(id)
			self
		end
		
		def line_up
			@now= 0
			@cutting_in= []
			@finished= []
			list= (0..(@parent.chars.size-1)).to_a
			if list.size>=2
				list.sort_by!{|id| @parent.chars[id].ability[:INI]}
				list.reverse!
			end
			list.unshift(:itv)
			list.push(:ode)
			list.delete(0)
			@list = list
		end
	end
	
	MAX_TENSION= 20
	class Character
		def initialize(name='', sess=nil, ability= Hash.new)
			@name= name
			@tension= 0
			@opened= 0
			@failed= false
			@chg= Challenge.new
			@ability= ability
			AbilityLabels.keys.each {|k| @ability[k] ||=0}
			@sess= sess
		end
		attr_reader :name, :tension, :opened, :chg, :sess
		attr_accessor :ability
		
		def state
			[@name, @tension, @opened, @failed, @ability.dup, @chg.state]
		end
		
		def state=(params)
			@name, @tension, @opened, @failed, @ability, @chg.state= *params
		end
		
		def failed?
			return @failed
		end
		
		def initiative(val=nil)
			if val
				@ability[:INI]= val
			end
			@sess.phase.line_up
			ini= sprintf('[先制=%d]', @ability[:INI])
			return @name.fit(10)+ ini
		end
		
		def gauge
			if self.failed?
				tension= MAX_TENSION- @opened
				space= 0
				over= @tension+ @opened- MAX_TENSION
			else
				tension= @tension
				space= MAX_TENSION- @tension- @opened
				over= 0
			end
			tension_str= 'X'*@opened+ '/'*tension+ '-'*space+ '*'*over
			tension_str= tension_str.scan(/.{1,5}/m).join(' ')
			tension_str= '['+ tension_str+ ']'
			tension_str= '【陥落】'+ tension_str if self.failed?
			
			ini= sprintf('[先制=%d]', @ability[:INI])
			
			str= ini+ @name.fit(10)+ tension_str
			return str
		end
		alias to_s gauge
		
		def impact(count)
			unless count.kind_of?(Integer) and count >= 0
				raise MisplayError, '0以上の整数を指定してください。'
			end
			@tension+= count
			@failed= true if (@tension+ @opened) >= MAX_TENSION
			self
		end
		
		def open(count)
			unless count.kind_of?(Integer) and count >= 0
				raise MisplayError, '0以上の整数を指定してください。'
			end
			if count > @tension
				raise MisplayError, '未開放のテンションが足りません。'
			end
			@opened+= count
			@tension-= count
			self
		end
		
		def delete(count)
			unless count.kind_of?(Integer) and count >= 0
				raise MisplayError, '0以上の整数を指定してください。'
			end
			if count > @opened
				raise MisplayError, '開放済のテンションが足りません。'
			end
			@opened-= count
			self
		end
		
		def say(said)
			@chg.say(said)
			return @chg
		end
		
		def roll(n=nil)
			@chg.roll(n)
			return @chg
		end
		
		def result(dummy=nil)
			return @chg.result
		end
		
		def hap(name, dice=nil, force=false)
			if force or @tension >= MAX_TENSION-5
				raise MisplayError, '出来事により陥落する危険があります。' 
			end
			unless @sess.haps[name].active
				raise MisplayError, "いま「#{name}」ではありません。"
			end
			unless dice
				dice= Dice.new(Array.new(2,Die.new))
				dice.roll
				dice= dice.results
			end
			self.impact((dice[0]-dice[1]).gcd(0))
			message = @sess.haps[name].hap(dice[0], dice[1])
			OdeLabels.each do |key, ode|
				if message =~ /#{ode}[+\s]*(\d*)/ then
					i = $1.to_i
					@sess.ode.sway(key,i)
				end
			end
			
			return sprintf("[%d][%d] %s", dice[0], dice[1], message)
		end
	end
	
	class Challenge
		def initialize
			@said= ''
			@fix= 0
			@dice= Array.new
			@rolled= false
		end
		attr_reader :said, :fix, :dice, :rolled
		
		def state
			[@said, @fix, @dice.dup, @rolled]
		end
		
		def state=(params)
			@said, @fix, @dice, @rolled= *params
		end
		
		def say(said)
			@said= said
			said= NKF.nkf('-Ze',@said)
			@rolled= false
			@fix= 0
			
			said += ' '
			n= 0
			pre= ''
			while said =~ /(\d{0,2})[dD][6\D]/
				n+= $1.to_i
				pre+= $`
				said= $'
			end
			said= pre+ said
			while said =~ /([+-]?\s?\d+)([\s\:\/\.\!\?\&\+\-])/
				said= $'
				said= $2+ said if $2
				@fix+= $1.sub(/\s/, '').to_i
			end
			@dice= Dice.new(Array.new(n,Die.new))
			
			return self
		end
		
		def roll(n=nil)
			if n
				raise MisplayError, 'まだロールしていません。' unless @rolled
				@dice[n-1].roll
			else
				@dice.roll
				@rolled= true
			end
			return self
		end
		
		def result(dummy=nil)
			raise MisplayError, 'まだロールしていません。' unless @rolled
			str= @said
			str+= ' => '
			str+= @fix.to_s+ '+'
			str+= @dice.results.map{|f| '['+f.to_s+']'}.join('')
			str+= ' = '+ (@fix+ @dice.result).to_s
			return str
		end
	end
end

if __FILE__ == $PROGRAM_NAME
end
