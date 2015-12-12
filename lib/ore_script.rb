require 'ore_script/parser'
require 'ore_script/evaluator'
require 'ore_script/builtin'
require 'forwardable'

module OreScript
  def self.run(src)
    ast = Parser.new.parse(src)
    #p ast: ast
    TypeCheck.new.check(ast)
    return Evaluator.new.eval(ast)
  end
end
