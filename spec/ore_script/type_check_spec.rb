require 'spec_helper'

module OreScript
  class TypeCheck
    describe 'TypeCheck' do
      def chk(src)
        TypeCheck::Type.reset
        ast = Parser.new.parse(src)
        subst, ty = TypeCheck.new.check(ast)
        return ty
      end

      describe "let" do
        it "mono" do
          expect(chk("x = 1 \n x")).to eq(NUMBER)
          src = <<-EOD
            f = fn(x){ add(x)(1) }
            y = 2
            f(y)
          EOD
          expect(chk(src)).to eq(NUMBER)
        end

        it "poly" do
          src = <<-EOD
            f = fn(x){ x }
            f(true)
            f(1)
            f
          EOD
          expect(chk(src)).to eq(TyFun[TyVar[6], TyVar[6]])
        end
      end

      it "exprs" do
        expect(chk("1 true")).to eq(BOOL)
      end

      it "function" do
        expect(chk("fn(x){ 1 }")).to eq(TyFun[TyVar[1], NUMBER])
        expect(chk("fn(x){ x }")).to eq(TyFun[TyVar[1], TyVar[1]])

        ty_x = TyVar[2]
        ty_f = TyFun[ty_x, TyVar[3]]
        expect(chk("fn(f){ fn(x){ f(x) }}")).to eq(
          TyFun[ty_f, TyFun[ty_x, TyVar[3]]]
        )
      end

      it "fcall" do
        expect(chk("add(1)(2)")).to eq(NUMBER)
      end

      it "ref" do
        expect(chk("add")).to eq(TyFun[NUMBER, TyFun[NUMBER, NUMBER]])
      end

      it "literal" do
        expect(chk("true")).to eq(BOOL)
        expect(chk("false")).to eq(BOOL)
        expect(chk("99")).to eq(NUMBER)
      end
    end
  end
end

