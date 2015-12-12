require 'spec_helper'

module OreScript
  class Evaluator
    describe 'Evaluator' do
      def run(src)
        ast = Parser.new.parse(src)
        return Evaluator.new.eval(ast)
      end

      it "let" do
        src = <<-EOD
          x = fn(x, y){ add(x, y) }
          x(7, 8)
        EOD
        expect(run(src)).to eq(Value::Number.new(15))
      end

      it "function" do
        expect(run("fn(x){ 1 }")).to be_a(Value::Function)
      end

      it "fcall, varref" do
        src = <<-EOD
          fn(x, y){ add(x, y) }(7, 8)
        EOD
        expect(run(src)).to eq(Value::Number.new(15))
      end

      it "if" do
        src = <<-EOD
          if(true) { 7 } else { 8 }
        EOD
        expect(run(src)).to eq(Value::Number.new(7))
        src = <<-EOD
          if(false) { 7 } else { 8 }
        EOD
        expect(run(src)).to eq(Value::Number.new(8))
      end

      it "literal" do
        expect(run("true")).to eq(Value::TRUE)
        expect(run("false")).to eq(Value::FALSE)
        expect(run("99")).to eq(Value::Number.new(99.0))
      end
    end
  end
end
