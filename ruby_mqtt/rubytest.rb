
class Test
  attr_accessor :m1
end

#p t1=Test.new
#p t1.respond_to?(:m1)
#p t1.send(:m1=,2)
#p t1.m1=2

#p ["a"].join(",")

#a,b=[1,2]
#p a
#p b

def method1(num,host,args={})
   p num
   p host
#   p topic
end

method1(1,2)
require './rubytest1.rb'
p T.new.name
