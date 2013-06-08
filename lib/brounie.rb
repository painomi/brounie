# -*- coding: Windows-31J -*-
$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require '../lib/brounie/brounie.rb'
require '../lib/brounie/brounie_bot.rb'

module Brounie
	VERSION = '0.2.0'
	HAPS_LIST= 'D:\\data\\TRPG\\少女展欄会\\チャート\\少女展覧会_出来事表_第2版.xls'
end
