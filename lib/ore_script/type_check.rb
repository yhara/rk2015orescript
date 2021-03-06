require 'forwardable'

module OreScript
  class TypeCheck
    class InferenceError < StandardError; end

    class Equation
      def initialize(ty1, ty2)
        raise TypeError.new("ty1: #{ty1.inspect}") unless ty1.is_a?(Type::Base)
        raise TypeError.new("ty2: #{ty2.inspect}") unless ty2.is_a?(Type::Base)
        @ty1, @ty2 = ty1, ty2
      end
      attr_reader :ty1, :ty2

      def swap; Equation.new(@ty2, @ty1); end

      def substitute!(s)
        @ty1 = @ty1.substitute(s)
        @ty2 = @ty2.substitute(s)
      end
    end

    module Type
      def self.reset; TyVar.reset; end

      class Base; end

      class TyRaw < Base
        def initialize(name)
          @name = name
        end
        attr_reader :name

        def ==(other); other.is_a?(TyRaw) && other.name == @name; end
        def inspect(inner=false); inner ? @name : "Ty(#{@name})"; end
        def substitute(subst); self; end
        def occurs?(id); false; end
        def var_ids; []; end
      end
      NUMBER = TyRaw.new("Number")
      BOOL = TyRaw.new("Bool")

      class TyVar < Base
        @@lastid = 0

        def self.reset; @@lastid = 0; end
        def self.[](id); new(id); end

        def initialize(id=nil)
          if id
            @id = id
          else
            @@lastid += 1
            @id = @@lastid
          end
        end
        attr_reader :id

        def ==(other); other.is_a?(TyVar) && other.id == @id; end
        def inspect(inner=false); inner ? "<#{@id.to_s}>" : "Ty(<#{@id}>)"; end
        def substitute(subst)
          if subst.key?(@id) then subst[@id] else self end
        end
        def occurs?(id); @id == id; end
        def var_ids; [@id]; end
      end

      class TyFun < Base
        def self.[](param_ty, ret_ty); new(param_ty, ret_ty); end

        def initialize(param_ty, ret_ty)
          raise if param_ty.is_a? Array
          @param_ty, @ret_ty = param_ty, ret_ty
        end
        attr_reader :param_ty, :ret_ty

        def ==(other)
          other.is_a?(TyFun) &&
            other.param_ty == @param_ty &&
            other.ret_ty == @ret_ty
        end

        def inspect(inner=false)
          [
            ("Ty(" if !inner),
            "#{@param_ty.inspect(true)} -> #{@ret_ty.inspect(true)}",
            (")" if !inner)
          ].join
        end

        def substitute(subst)
          TyFun.new(@param_ty.substitute(subst),
                    @ret_ty.substitute(subst))
        end
        def occurs?(id)
          @param_ty.occurs?(id) || @ret_ty.occurs?(id)
        end
        def var_ids
          @param_ty.var_ids + @ret_ty.var_ids
        end
      end
    end
    include Type

    # Type environment
    class TypeEnv
      extend Forwardable

      def initialize(hash={})
        @hash = hash  # String(ident) => Type
      end

      def inspect
        "#<TypeEnv%p>" % [@hash]
      end

      def_delegators :@hash, :key?, :[], :[]=, :inject

      def merge(hash)
        TypeEnv.new(@hash.merge(hash))
      end

      def substitute(subst)
        TypeEnv.new(@hash.map{|name, ts| [name, ts.substitute(subst)]}
                        .to_h)
      end
    end

    # Represents type substitution
    class Subst
      extend Forwardable

      # Create new subst with one substitution
      def self.[](id, ty)
        Subst.new({id => ty})
      end

      # Create new empty subst
      def self.empty
        Subst.new({})
      end

      # Create new subst from hash (id(Integer) => type)
      def initialize(hash={})
        @hash = hash
      end

      def inspect
        "#<Subst#{@hash.inspect}>"
      end

      def_delegators :@hash, :key?, :[], :==

      def to_h
        @hash
      end

      # Add a substitution {id => type} to this subst
      def add!(id, type)
        ss = Subst.new({id => type})
        # Substitute +id+ with +type+ before adding {id => type}
        @hash = @hash.map{|_id, _ty| [_id, _ty.substitute(ss)]}
                     .to_h
                     .merge({id => type})
      end

      # Merge one or more substs using TypeInference.unify
      def merge(*others)
        unless others.all?{|x| x.is_a?(Subst)}
          raise TypeError, "some not a subst: #{others.inspect}"
        end
        equations = ([self]+others).flat_map(&:to_equation)
        return TypeCheck.unify(*equations)
      end

      # Convert this subst into a Equation
      def to_equation
        @hash.map{|id, ty|
          Equation.new(Type::TyVar.new(id), ty)
        }
      end
    end

    def check(ast)
      env = TypeEnv.new(
        Builtin::FUNCTIONS.map{|name, (ty, _)|
          [name, ty]
        }.to_h
      )
      infer(env, ast)
    end

    # - env : Hash(String => Ty)
    # Returns [subst, type]
    def infer(env, node)
      case node.first
      when :literal
        _, typename, val = *node

        [Subst.empty, TyRaw.new(typename)]
      when :varref
        _, name = *node

        raise InferenceError, "Variable #{name} not found" if not env.key?(name)
        [Subst.empty, env[name]]
      when :fcall
        _, func_expr, arg_expr = *node
        result_type = TyVar.new

        s1, func_type = infer(env, func_expr)
        s2, arg_type = infer(env.substitute(s1), arg_expr)

        func_type = func_type.substitute(s2)
        equation = Equation.new(func_type, TyFun.new(arg_type, result_type))
        s3 = TypeCheck.unify(equation)

        [s1.merge(s2, s3), result_type.substitute(s3)]
      when :function
        _, name, body = *node

        arg_type = TyVar.new
        newenv = env.merge(name => arg_type)
        s, t = infer(newenv, body)
        [s, TyFun.new(arg_type, t).substitute(s)]
      when :let
        _, name, expr = *node

        s, var_ty = infer(env, expr)

        env[name] = var_ty
        [s, var_ty]
      when :exprs
        _, exprs = *node

        exprs.reduce([Subst.empty, nil]){|(s, ty), expr|
          s_, ty_ = infer(env, expr)
          [s.merge(s_), ty_]
        }
      else
        raise ArgumentError, "unkown node: #{node.inspect}"
      end
    end

    private

    def self.unify(*equations)
      subst = Subst.empty
      eqs = equations.dup

      until eqs.empty?
        con = eqs.pop
        ty1, ty2 = con.ty1, con.ty2
        case
        when ty1.is_a?(TyFun) && ty2.is_a?(TyFun)
          eqs.push Equation.new(ty1.param_ty, ty2.param_ty)
          eqs.push Equation.new(ty1.ret_ty, ty2.ret_ty)
        when ty1.is_a?(TyVar)
          next if ty2 == ty1
          
          id = ty1.id
          raise InferenceError if ty2.occurs?(id)

          subst.add!(id, ty2)
          eqs.each{|c| c.substitute!(Subst.new({id => ty2})) }
        when ty2.is_a?(TyVar)
          eqs.push con.swap
        when ty1.is_a?(TyRaw) && ty2.is_a?(TyRaw)
          if ty1 != ty2
            raise InferenceError, "type mismatch: %p vs %p" % [ty1, ty2]
          end
        else
          raise "no match (con: #{con.inspect})"
        end
      end

      return subst
    end
  end
end

if $0 == __FILE__
  $LOAD_PATH.unshift "#{__dir__}/.."
  require 'ore_script'
  class OreScript::TypeCheck
    tc = OreScript::TypeCheck.new
    ast = OreScript::Parser.new.parse("f = fn(x){ add(x)(1) }")
        env = TypeEnv.new(
          OreScript::Builtin::FUNCTIONS.map{|name, (ty, _)|
            [name, TypeScheme.new([], ty)]
          }.to_h
        )
    p tc.infer(env, ast)
  end
end
