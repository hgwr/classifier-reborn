$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'classifier-reborn'

if ENV['JUMAN_CMD'].nil?
  ENV['JUMAN_CMD'] = '/opt/juman-7.01/bin/juman'
end

include ClassifierReborn
