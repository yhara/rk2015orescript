require 'ore_script/evaluator'
require 'ore_script/type_check'

module OreScript
  module Builtin
    include TypeCheck::Type

    num = ->(n){ Evaluator::Value::Number.new(n) }
    bool = ->(x){ x ? Evaluator::Value::TRUE : Evaluator::Value::FALSE }

    FUNCTIONS = {
      "add" => [TyFun[NUMBER, TyFun[NUMBER, NUMBER]], ->(x, y){
        num[x.value + y.value]
      }.curry],
      "sub" => [TyFun[NUMBER, TyFun[NUMBER, NUMBER]], ->(x, y){
        num[x.value - y.value]
      }.curry],
      "mul" => [TyFun[NUMBER, TyFun[NUMBER, NUMBER]], ->(x, y){
        num[x.value * y.value]
      }.curry],
      "div" => [TyFun[NUMBER, TyFun[NUMBER, NUMBER]], ->(x, y){
        num[x.value / y.value]
      }.curry],
      "mod" => [TyFun[NUMBER, TyFun[NUMBER, NUMBER]], ->(x, y){
        num[x.value % y.value]
      }.curry],
      "sqrt" => [TyFun[NUMBER, NUMBER], ->(x){
        num[Math.sqrt(x.value)]
      }.curry],
      "is_zero" => [TyFun[NUMBER, BOOL], ->(x){
        bool[x.value.zero?]
      }.curry],
      "is_odd" => [TyFun[NUMBER, BOOL], ->(x){
        bool[x.value.odd?]
      }.curry],
      "is_even" => [TyFun[NUMBER, BOOL], ->(x){
        bool[x.value.even?]
      }.curry],
      "printn" => [TyFun[NUMBER, NUMBER], ->(n){
        if n.value % 1 == 0
          print n.value.to_i
        else
          print n.value
        end
        n
      }.curry],
      "printc" => [TyFun[NUMBER, NUMBER], ->(n){
        print n.value.chr
        n
      }.curry],
    }
  end
end
