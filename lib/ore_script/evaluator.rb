require 'forwardable'

module OreScript
  class Evaluator
    class Value
      TRUE = Object.new
      FALSE = Object.new
      Number = Struct.new(:value)
      Function = Struct.new(:env, :param_name, :body_exprs)
    end

    def eval(ast)
      env = Builtin::FUNCTIONS.map{|name, (ty, prc)|
        [name, prc]
      }.to_h
      eval_expressions(env, ast)
    end

    def eval_expressions(env, exprs)
      unless exprs.is_a?(Array) && exprs[0] == :exprs
        raise "bad exprs: #{exprs.inspect}"
      end
      ret = nil
      exprs[1].each do |expr|
        ret = eval_expression(env, expr)
      end
      ret 
    end

    def eval_expression(env, expr)
      case expr[0]
      when :let
        eval_let(env, expr[1], expr[2])
      when :function
        eval_function(env, expr[1], expr[2])
      when :fcall
        eval_fcall(env, expr[1], expr[2])
      when :if
        eval_if(env, expr[1], expr[2], expr[3])
      when :varref
        eval_varref(env, expr[1])
      when :literal
        eval_literal(env, expr[2])
      else
        raise "unknown expr: #{expr.inspect}"
      end
    end

    def eval_let(env, var_name, expr)
      env[var_name] = eval_expression(env, expr)
    end

    def eval_function(env, param_name, body_exprs)
      Value::Function.new(env, param_name, body_exprs)
    end

    def eval_fcall(env, func_expr, arg_expr)
      func = eval_expression(env, func_expr)
      arg = eval_expression(env, arg_expr)

      case func
      when Value::Function
        newenv = func.env.merge(func.param_name => arg)
        eval_expressions(newenv, func.body_exprs)
      when Proc # builtin
        func.call(arg)
      else
        raise "expected Function but got #{func.inspect}"
      end
    end

    def eval_varref(env, varname)
      env.fetch(varname)
    end

    def eval_literal(env, value)
      case 
      when value == true
        Value::TRUE
      when value == false
        Value::FALSE
      when value.is_a?(Numeric)
        Value::Number.new(value)
      else
        raise "unknown literal: #{value.inspect}"
      end
    end
  end
end
