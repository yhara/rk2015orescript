module OreScript
  class TypeCheck
    class InferenceError < StandardError; end

    class Constraint
      def initialize(ty1, ty2)
        raise TypeError.new("ty1: #{ty1.inspect}") unless ty1.is_a?(Type::Base)
        raise TypeError.new("ty2: #{ty2.inspect}") unless ty2.is_a?(Type::Base)
        @ty1, @ty2 = ty1, ty2
      end
      attr_reader :ty1, :ty2

      def swap; Constraint.new(@ty2, @ty1); end

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
      NUMBER = TyRaw.new("number")
      BOOL = TyRaw.new("bool")

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
        def self.[](param_tys, ret_ty); new(param_tys, ret_ty); end

        def initialize(param_tys, ret_ty)
          raise "param_tys not array" unless param_tys.is_a?(Array)
          @param_tys, @ret_ty = param_tys, ret_ty
        end
        attr_reader :param_tys, :ret_ty

        def ==(other)
          other.is_a?(TyFun) &&
            other.param_tys == @param_tys &&
            other.ret_ty == @ret_ty
        end

        def inspect(inner=false)
          params = @param_tys.map{|x| x.inspect(true)}.join(", ")
          [
            ("Ty(" if !inner),
            "[#{params}] -> #{@ret_ty.inspect(true)}",
            (")" if !inner)
          ].join
        end

        def substitute(subst)
          TyFun.new(@param_tys.map{|x| x.substitute(subst)},
                    @ret_ty.substitute(subst))
        end
        def occurs?(id)
          @param_tys.any?{|x| x.occurs?(id)} || @ret_ty.occurs?(id)
        end
        def var_ids
          @param_tys.flat_map(&:var_ids) + @ret_ty.var_ids
        end
      end
    end
    include Type

    class TypeScheme
      # - ids : Array of Fixnum
      def initialize(ids, type)
        @ids = ids.uniq
        @type = type
      end
      attr_reader :ids, :type

      def inspect(inner=false)
        "#<TS(%s) %p>" % [@ids.join(","), @type]
      end

      def substitute(subst)
        TypeScheme.new(@ids, @type.substitute(subst))
      end

      # Create (monomorphic) type from this type scheme
      def instantiate
        # Already monomorphic
        return @type if @ids.empty?

        # Substitute type variable with fresh (monomorphic) TyVar 
        subst = Subst.new(@ids.map{|id|
          [id, Type::TyVar.new]
        }.to_h)
        return @type.substitute(subst)
      end

      # Variables of outer environment
      def free_type_ids
        @type.var_ids - @ids
      end
    end

    # Type environment
    class TypeEnv
      extend Forwardable

      def initialize(hash={})
        @hash = hash  # String(ident) => TypeScheme
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

      # Create polymorphic typescheme
      def generalize(type)
        # Collect free type ids from type schemes
        free_type_ids = @hash.values.flat_map(&:free_type_ids)

        # Type variables = Types contained in `type`
        # except free types (i.e. types defined in elsewhere)
        typevars = type.var_ids - free_type_ids
        return TypeScheme.new(typevars, type)
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
        constraints = ([self]+others).flat_map(&:to_constr)
        return TypeCheck.unify(*constraints)
      end

      # Convety2 this subst into a Constraint
      def to_constr
        @hash.map{|id, ty|
          Constraint.new(Type::TyVar.new(id), ty)
        }
      end
    end

    def check(ast)
      env = TypeEnv.new(
        Builtin::FUNCTIONS.map{|name, (ty, _)|
          [name, TypeScheme.new([], ty)]
        }.to_h
      )
      infer(env, ast)
    end

    # - env : Hash(String => TypeScheme)
    # Returns [subst, type]
    def infer(env, node)
      case node.first
      when :literal
        _, typename, val = *node

        [Subst.empty, TyRaw.new(typename)]
      when :varref
        _, name = *node

        raise InferenceError, "Variable #{name} not found" if not env.key?(name)
        [Subst.empty, env[name].instantiate]
      when :fcall
        _, func_expr, arg_exprs = *node
        result_type = TyVar.new

        s1, func_type = infer(env, func_expr)

        init = [s1, env.substitute(s1), []]
        s2, _, arg_types = arg_exprs.reduce(init) do |(s_, env_, tys), expr|
          ss, ty = infer(env_, expr)
          [s_.merge(ss), env_.substitute(ss), tys + [ty]]
        end

        func_type = func_type.substitute(s2)
        s3 = TypeCheck.unify(
          Constraint.new(func_type,
                         TyFun.new(arg_types, result_type))
        )

        [s1.merge(s2, s3), result_type.substitute(s3)]
      when :function
        _, names, body_expr = *node
        arg_types = names.map{ TyVar.new }
        newenv = env.merge(
          names.zip(arg_types).map{|name, ty|
            [name, TypeScheme.new([], ty)]
          }.to_h
        )
        s, t = infer(newenv, body_expr)
        [s, TyFun.new(arg_types, t).substitute(s)]
#      when :let_
#        _, name, var_expr, body_expr = *node
#
#        s1, var_type = infer(env, var_expr)
#        newenv = env.substitute(s1)
#        var_ts = newenv.generalize(var_type)
#
#        s2, body_type = infer(newenv.merge(name => var_ts), body_expr)
#
#        [s1.merge(s2), body_type]
      when :let
        _, name, expr = *node

        s, var_ty = infer(env, expr)
        var_ts = env.substitute(s).generalize(var_ty)

        env[name] = var_ts
        [s, var_ty]
      when :exprs
        _, exprs = *node

        exprs.reduce([Subst.empty, nil]){|(s, ty), expr|
          s_, ty_ = infer(env, expr)
          [s.merge(s_), ty_]
        }
      when :if
        _, cond_expr, then_exprs, else_exprs = *node

        s1, ty1 = infer(env, cond_expr)
        env = env.substitute(s1)
        s2, ty2 = infer(env, then_exprs)
        env = env.substitute(s2)
        s3, ty3 = infer(env, else_exprs)

        s4 = TypeCheck.unify(
          Constraint.new(ty1, Type::BOOL),
          Constraint.new(ty2, ty3)
        )
        [s1.merge(s2, s3, s4), ty2.substitute(s4)]
      else
        raise ArgumentError, "unkown node: #{node.inspect}"
      end
    end

    private

    def self.unify(*constraints)
      subst = Subst.empty
      consts = constraints.dup

      until consts.empty?
        con = consts.pop
        ty1, ty2 = con.ty1, con.ty2
        case
        when ty1.is_a?(TyFun) && ty2.is_a?(TyFun)
          if ty1.param_tys.length != ty2.param_tys.length
            raise InferenceError, "arity mismatch: %p vs %p" % [ty1, ty2]
          end
          consts.concat(
            ty1.param_tys.zip(ty2.param_tys).map{|l, r|
              Constraint.new(l, r)
            }
          )
          consts.push Constraint.new(ty1.ret_ty, ty2.ret_ty)
        when ty1.is_a?(TyVar)
          next if ty2 == ty1
          
          id = ty1.id
          raise InferenceError if ty2.occurs?(id)

          subst.add!(id, ty2)
          consts.each{|c| c.substitute!(Subst.new({id => ty2})) }
        when ty2.is_a?(TyVar)
          consts.push con.swap
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

