require 'ore_script/evaluator'
require 'ore_script/type_check'

module OreScript
  module Builtin
    include TypeCheck::Type

    num = ->(n){ Evaluator::Value::Number.new(n) }
    bool = ->(x){ x ? Evaluator::Value::TRUE : Evaluator::Value::FALSE }

    FUNCTIONS = {
      "add" => [TyFun[[NUMBER, NUMBER], NUMBER], ->(x, y){
        num[x.value + y.value]
      }],
      "sub" => [TyFun[[NUMBER, NUMBER], NUMBER], ->(x, y){
        num[x.value - y.value]
      }],
      "mul" => [TyFun[[NUMBER, NUMBER], NUMBER], ->(x, y){
        num[x.value * y.value]
      }],
      "div" => [TyFun[[NUMBER, NUMBER], NUMBER], ->(x, y){
        num[x.value / y.value]
      }],
      "mod" => [TyFun[[NUMBER, NUMBER], NUMBER], ->(x, y){
        num[x.value % y.value]
      }],
      "sqrt" => [TyFun[[NUMBER], NUMBER], ->(x){
        num[Math.sqrt(x.value)]
      }],
      "is_zero" => [TyFun[[NUMBER], BOOL], ->(x){
        bool[x.value.zero?]
      }],
      "is_odd" => [TyFun[[NUMBER], BOOL], ->(x){
        bool[x.value.odd?]
      }],
      "is_even" => [TyFun[[NUMBER], BOOL], ->(x){
        bool[x.value.even?]
      }],
    }
  end
end
