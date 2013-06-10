require 'nkf'

class ParseError < StandardError ; end

class Die
	def initialize(face = 6)
		@face = face.to_i
		case @face
		when 2, 4, 6, 8, 10, 12, 20, 100;
		else
			raise ArgumentError, @face.to_s
		end
		@result
	end
	
	attr_reader :result, :face
	alias to_i result
	
	def to_s
		"D#{@face}"
	end
	
	def <=>(other)
		result = @face <=> other.face
		result.zero? ? @result.to_i <=> other.result.to_i : result
	end
	
	def cast
		@result = rand(@face) + 1
	end
	
	def roll
		[cast]
	end
end

class Dice
	def initialize(dice= [Die.new, Die.new])
		@result = 0
		@results = Array.new
		case dice
		when Array
			@dice = dice
		when Die
			@dice = [dice]
		end
	end
	attr_reader :result, :results
	
	def to_s
		@dice.map{|d| '['+d.to_s+']'}.join('')
	end
	
	def size
		@dice.size
	end
	
	def roll
		@result = 0
		@results = Array.new
		@dice.each do |die|
			@result += die.cast
			@results.push(die.result)
		end
		return @result
	end
	
	def each
		@dice.each{|die| yield die}
	end
	
	def [](n)
		@dice[n]
	end
end

class DiceRoll
	def initialize(said='', fix=0, dice=Array.new, d66=0)
		@said = said
		@fix  = fix
		@dice = dice
		@d66  = d66
	end
	
	def self.parse(said)
		msg= said
		said= NKF.nkf('-Ze', said)
		fix= 0
		d66= 0
		said += ' '
		
		pre= ''
		while said =~ /(\D)?[dD]66/
			d66+= 1
			pre+= $`
			pre+= $1 if $1
			said= $'
		end
		said= pre+ said
		
		n= 0
		pre= ''
		while said =~ /(\d{0,2})[dD][6\D]/
			n+= $1.to_i
			pre+= $`
			said= $'
		end
		said= pre+ said
		
		while said =~ /([+-]?\s?\d+)([\D])/
			said= $'
			said= $2+ said if $2
			fix+= $1.sub(/\s/, '').to_i
		end
		dice= Array.new(n, Die.new)
		
		if fix==0 and dice.size==0 and d66==0
			return nil
		else
			return DiceRoll.new(msg, fix, dice, d66)
		end
	end
	
	def roll
		str= @said + ' => '
		
		if @d66 > 0
			d= []
			d << Die.new.cast
			d << Die.new.cast
			d.sort
			str+= ' ['+ d.join('')+ '] '
		end
		
		if @fix > 0 or @dice.size > 0
			result= []
			@dice.each{|d| result<< d.cast}
			result.sort!.reverse!
			str+= @fix.to_s+ '+'
			str+= result.map{|r| '['+ r.to_s+ ']'}.join('')
			str+= ' = '+ (@fix+ result.inject{|sum, r| sum+ r }).to_s
		end
		
		return str
	end
end

