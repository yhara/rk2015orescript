require 'forwardable'

module OreScript
  class Evaluator
    class Value
      TRUE = Object.new
      FALSE = Object.new
      Number = Struct.new(:value)
      Function = Struct.new(:env, :param_names, :body_exprs)
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

    def eval_function(env, param_names, body_exprs)
      Value::Function.new(env, param_names, body_exprs)
    end

    def eval_fcall(env, func_expr, arg_exprs)
      func = eval_expression(env, func_expr)
      args = arg_exprs.map{|x| eval_expression(env, x)}

      case func
      when Value::Function
        if args.length != func.param_names.length
          raise "wrong number of args: "+
                "#{args.length} for #{func.param_names.length}"
        end
        newenv = func.env.merge( func.param_names.zip(args).to_h )
        eval_expressions(newenv, func.body_exprs)
      when Proc # builtin
        if args.length != func.arity
          raise "wrong number of args: #{args.length} for #{func.arity}"
        end
        func.call(*args)
      else
        raise "expected Function but got #{func.inspect}"
      end
    end

    def eval_if(env, cond_expr, then_exprs, else_exprs)
      cond = eval_expression(env, cond_expr)
      case cond
      when Value::TRUE
        eval_expressions(env, then_exprs)
      when Value::FALSE
        eval_expressions(env, else_exprs)
      else
        raise "expected Bool but got #{cond.inspect}"
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
