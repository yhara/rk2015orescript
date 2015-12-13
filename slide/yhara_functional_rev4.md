  footer: RubyKaigi 2015
  slidenumbers: true
autoscale: true

### 関数型言語を作ろう

### Let's Make a Functional Language!

#### RubyKaigi2015<br><br>![inline](nacl.jpg)<br><br>yhara (Yutaka Hara)

---

# Or:

### Rubyistのための型推論入門

### Type Inference 101 for Rubyist

#### RubyKaigi2015<br><br>![inline](nacl.jpg)<br><br>yhara (Yutaka Hara)

---

## Agenda

1. What is "Type Inference?"
2. Hindley-Milner type system
3. Implementation

- [https://github.com/yhara/rk2015orescript](https://github.com/yhara/rk2015orescript)

^本日のアジェンダです。まず最初に、型推論って何だろうという話をします。型推論にもいろいろあるのですが、今日はHaskellやOCamlといった言語の基礎になっているHindley-Milner型推論を取り上げます。そのあとに具体的な実装の話をします。

^ スライドとソースコードはgithubに上げてあるので、何か質問があればIsusesやTwitterで聞いて下さい。僕は型理論の専門家ではないので、間違いがあったらすみません。

---

## OreScript

```
f = fn(x){ printn(x) }
f(2)   //→ 2
```

^ 今日、このセッションで作る言語はOreScriptといいます。Oreは英語だとダイヤモンドとかルビーといった「鉱石」の意味ですが、それはあんまり関係なくて、日本語の一人称である「俺」から付けました。

---

## Difference from JavaScript

```
f = fn(x){ printn(x) }
f(2)   //→ 2
```

- No semicolon
- s/function/fn/

^ これはOreScriptのサンプルコードです。Rubyにも似ていますが、どちらかというとRubyよりもJavaScriptに一番近いです。が、セミコロンが要らなくしているのと、関数を作るのに「function」と書くのは面倒すぎるので、OreScriptでは「fn」を関数のための予約語にしているところが違います。

---

## Myself

- @yhara (Yutaka Hara)
- ![inline](nacl.jpg) (Matsue, Shimane)
- Making software with Ruby

^さて本題に入る前に、簡単に自己紹介をさせて下さい。twitterやgithubでは、@yharaという名前を使っています。 今は島根県松江市に住んでいて、NaCl、ネットワーク応用通信研究所という会社で、Rubyを使ってソフトウェアを開発する仕事をしています。

---

## My blog[^1]

![inline](blog.png)

[^1]: [http://route477.net/d/](http://route477.net/d/)

^ こういう緑のブログを書いています。

---

## Me and Ruby

- Enumerable#lazy (Ruby 2.0~)
  - Note: I'm not a Ruby committer
- [TRICK](https://github.com/tric/trick2015) judge
- 『Rubyで作る奇妙なプログラミング言語』(Making Esoteric Language with Ruby)

![right 20%](esobook.jpg)

^Ruby関係では、Ruby 2.0から入ったEnumerable#lazyというメソッドの提案者です。Rubyに機能を提案したりしているので、たまにコミッタだと間違われることがあるのですが、コミッタではありません。あとTRICKの審査委員をしたのと、『Rubyで作る奇妙なプログラミング言語』という本の著者です。

---

## 1. What is "Type Inference"?

^ さて、今日は型推論の話をするのでした。Ruby 3.0にも型推論が入るみたいな話もありますが、型推論って一体何なのでしょうか。

---

## What is "Type"?

- Type = Group of values
  - 1,2,3, ... => Integer
  - "a", "b", "c", ... => String
      
^ 型推論について考えるためには、まず「型」とは何なのかを明らかにする必要があります。Rubyを使っているとあまり意識することはないかもしれませんが、「型」とは「値の分類」のことです。例えば1,2,3などの値は「整数」に、"a","b","c"などの値は「文字列」に分類されます。

---

## What is "Type"?

- Ruby has type, too! (Integer, String,...)
- Ruby variables do not have type, though
  ```
  a = 1
  a = "str"   # ok 
  ```
- This is error in C
  ```
  int a = 1;
  a = "str";  // compile error!
  ```

^ この意味において、Rubyにも型は存在します。よく「型のない言語」などと言ったりしますが、それは厳密にいうと「変数に型がない言語」のことです。Rubyでは変数に型がないので、一回数値を入れた変数に、そのあとで文字列を入れなおすことができます。一方変数に型があるC言語などでは、「この変数は整数を入れます」と宣言(declare)するので、文字列を入れようとするとエラーになります。

---

## Pros of static typing

1. Optimization
2. Type check

```rb
def foo(user)
  print user.name
end

foo(123)
#=> NoMethodError: undefined method `name' for 123:Fixnum
```

^ある変数に決まった型の値しか入れられないというのは、窮屈に感じるかもしれません。変数の型を決めると、どんな良いことがあるのでしょうか？

^ 1つは、最適化のためですが、もう一つは、型チェックのためです。Rubyでも、userという変数になぜか整数が入っていて「nameというメソッドはありません」と怒られるとか、よくあると思います。メソッド引数の型をあらかじめ宣言するような言語では、Userを引数にとるメソッドに数値を渡そうとした場合はコンパイルエラーになるので、プログラムを実行することなくバグを検出することができます。

---

## Cons of static typing

- Type annotation?

```
Array<Integer> ary = [1,2,3]
ary.map{|Integer x|
    x.to_s
} 
```
 
^ では逆に、型を宣言することのデメリットは何でしょうか。それにはいろいろありますが、一つは「型を書くのがめんどくさい」ということです。 例えば、もしRubyが突然、静的型言語に変身したらどうなるか考えてみましょう。変数の型を書くくらいならまだいいかもしれないですが、ブロックパラメータにも型を書かないといけないとなると、ちょっと面倒ですよね。

---

## Type inference

```hs
-- Haskell
ary = [1,2,3]
map (\x -> show x) ary
```

- No type annotations here


^ 一方、関数型言語の一つであるHaskellは、静的型言語であるにもかかわらず、下のように全く型を書く必要がありません。変数xは自動的に、整数が入るものだと推論されます。 これが型推論です。

---

## RECAP

- Type = Group of values
  - Static typing
      - Check type errors
      - Optimization
  - Don't want to write type annotations
    => Type Inference

^ ここまでのまとめです。型は値を分類したもので、静的型付け言語では型を使ってプログラムのチェックや最適化を行うのでした。一方、プログラムのすべての箇所に明示的に型指定を書くのは大変です。これを改善するため、型を書かなくてもプログラマの意図を推論してくれる仕組みが型推論です。

---

## Various "Type Inference"

- C#:
  - `var ary = [1,2,3];`
- Haskell, OCaml:
  - Can omit type of function arguments, etc. 
  - Hindley-Milner type system
  
^ 最も、単に「型推論」と言っても、具体的な内容は言語によって違ったりします。例えばC#だと、変数を宣言するとき、初期値があれば型を省略することができる…という機能が「型推論」と呼ばれていたりするようです。メソッドの引数の型などは省略することができません。 ところがHaskellやOCamlといった言語では、関数の引数の型も含めて省略することができます。これらの言語は、「Hindley-Milner型システム」というものをベースにしています。 

---

## 2. Hindley-Milner type system

^ さてここからは、先ほど名前が出てきたHindley-Milner型システムの話をします。

---

## What is "type system"?

- System of types, of course :-)
- Set of rules about type
  - Decides which type an expression will have  
  - Decides which types are compatible 
      - eg. Inheritance
- Every language has its own type system

^ 型システムという言葉が出てきましたが、型システムって何でしょうか。まあ型のシステムのことなんですが、もうちょっと詳しくいうと、型に関するルールの集まりのことですね。例えばある式がどんな型を持つのかとか、どの型とどの型が互換性があるのかとか。互換性というのは、例えば継承とかですね。親クラスの型で宣言した変数には、子クラスのインスタンスを入れられるとかありますよね。

^ こういう話なので、型システムというのは言語によって違います。JavaにはJavaの、ScalaにはScalaの型システムがあります。

---

## What is "type system"?

- Hindley-Milner type system
  - Haskell = HM + type class + ...
  - OCaml = HM + variant + ...
  - OreScript = HM (slightly modified)
- Has an algorithm to reconstruct types
  - without any type annotation(!)

^ HaskellやOCamlの型システムは、HM型システムというものがベースになっています。HM型システムには、型がまったく書かれていなくても型を復元できるという性質があります。OreScriptもこれをベースにしています。

---

## OreScript language spec

- Literal
  - eg. `99`, `true`, `false`
- Anonymous function
  - eg. `fn(x){ x }`
- Variable definition
  - eg. `x = 1`
  - eg. `f = fn(x){ x }`
  - (Note: You can't reassign variables)
- Function call
  - eg. `f(3)`

^ OreScriptの言語仕様です。

---

## Only unary function is supported

- Don't worry, you can emulate binary function

```
f = fn(x, y){ ... }
f(1, 2)

　　↓

f = fn(x){ fn(y){ ... } }
f(1)(2)
```

^ 1引数の関数しかサポートしていないのですが、2引数以上の関数もエミュレートできるので安心して下さい。

---

## Type system of OreScript

- <type> is any one of ...
  - Bool
  - Number
  - <type> → <type>
      - eg. `is_odd :: Number → Bool`
- Checks
  - Type of `a` and `x` must be the same

```
f = fn(a){ ... }
f(x)
```

^ OreScriptの型システムです。まあ型システムというほどのものはなくて、ブール型と数値型だけがあります。あとはそれらの関数型ですね。例えば組み込み関数のis_oddは、数値を取って真偽値を返す関数になります。本スライドでは、コロン二つである式の型を示すことにします。関数型は、矢印で表記します。

^ で、型に関する決まりとしては、「関数呼び出しの際は、実引数と仮引数の型が同じでなければならない」というのがあります。一番下の例だと、aとxは同じ型でないといけません。まあこれは当たり前ですよね。

---

## Type inference of OreScript

- Given
  -  `f = fn(x){ is_odd(x) }`
  - is_odd :: Number → Bool 
- step1 Assumption
  - f :: (1) → (2)
  - x :: (3)
- step2 Equations
  - (1) == (3), (3) == Number, (2) == Bool
- step3 Resolve
  - (1) == Number, (2) == Bool, (3) == Number
  - f :: Number → Bool 

^ ではHM型推論の様子を見てみましょう。1行目で、fという関数を定義しています。fの型は何か分からないですが、関数らしいということは分かるので、1番から2番への関数だとおいておきます。(このスライドでは、「::」という表記で「これの型はこれだよ」というのを示します。また矢印で関数の型を示します。) 続いて関数の引数を見るとxという変数があります。これの型も最初は分からないので3番とします。is_oddは組み込み関数で、数値から真偽値への関数であるとします。

^ このとき、プログラムをよく見るといくつかのことが分かります。まず、変数xはfの引数なので、1番と3番は同じ型でなくてはいけません。またxはis_oddの引数に渡しているので、3番はNumber型でないといけません。さらに、is_oddの返り値がfの返り値になるので、2番はBool型でないといけません。

^ これら3つの等式を解くと、1番はNumber、2番はBool、3番はNumberであることがわかります。そうすると、fは1番から2番への関数だったので、NumberからBoolへの関数であるとわかりました。

^ このようにHM型推論では、「分からないところは仮に1番、2番としておく」「これとこれは同じ型であるはず、という条件を列挙する」「条件の等式を問いて、それぞれの型を求める」という手順で型を割り出します。

---

## RECAP

- Type system = set of rules on types
- Hindley-Minler type system
  - Reconstruct types without annotation
  - Assume, Build equations, Resolve

^ ここまでのまとめです。「型システム」は型に関するルールのことで、HaskellやOCamlなどの型システムはHindley-Milner型システムというものをベースにしているのでした。HM型システムは型をまったく書かずに型を復元できるという特徴がありました。手順としては、型がわからないところを仮定し、型が同じでなければならないところを列挙して、等式を解くのでした。

---

## 3. Implementation of OreScript

^ HM型推論の概要について説明したところで、ここからはOreScript言語の実装について見ていきましょう。

---

## bin/ore_script

```
$ cat a.ore
printn(123)
$ ./bin/ore_script a.ore
123
```

^ bin/ore_scriptというところに実行ファイルがあります。こんな風に使います。

---

## bin/ore_script

```rb
#!/usr/bin/env ruby
require 'ore_script'

# 1. Parse
tree = OreScript::Parser.new.parse(ARGF.read)
# 2. Type check
OreScript::TypeCheck.new.check(tree)
# 3. Execute
OreScript::Evaluator.new.eval(tree)
```

^ 中身はこんな風になっています。1, 2, 3と3つのステップがありますが、説明の都合上、1, 3, 2の順で説明していきます。

---

## 1. OreScript::Parser

- Convert source code into a tree (parse tree)

  `fn(x){ add(x)(1) }`

![right fit](ast.png)


^ プログラミング言語の処理系を作る場合、入力としてはソースコードが文字列として渡されてきて、これを実行して下さいと言われるわけですが、ソースコードって、文字列のままでは扱いづらいんですね。

^ ソースコードをどのように扱えばいいかですが、これはある程度決まった、定番のパターンがあって、それは「木構造を作る」ということです。 例えばこのソースコードであれば、だいたいこんな感じの木になります。

---

## Parser library for Ruby

- racc gem
- treetop/parslet/citrus gem
- Write by hand
  - Recursive Descent Parsing
  - eg. https://github.com/yhara/esolang-book-sources/blob/master/bolic/bolic.rb
  
^ 構文解析というのは歴史の長い分野なので、Rubyでもたくさんのライブラリがありますが、今回はraccというgemを使います。

---

## racc gem

parser.ry:

```
    expression : let
               | function
               | fcall
               | if
               | varref
               | literal
               | '(' expression ')'
    let : VAR '=' expression
    function : 'fn' '(' params ')' '{' expressions '}' 
    fcall : expression '(' args ')'
    if : 'if' '(' expression ')' '{' expressions '}'
         'else' '{' expressions '}'
...
```

^ raccでは.ryというファイルを作って、こんな感じで文法を定義します。そうすると、そこからパースを行うRubyスクリプトを生成してくれます。

---

## Result of parsing

`fn(x){ add(x)(1) }`

```
[:exprs,
 [[:function,
   "x",
   [:exprs,
    [[:fcall,
      [:fcall, [:varref, "add"], [:varref, "x"]],
      [:literal, "Number", 1.0]]]]]]]
```

^ パースした結果、どのようなデータ構造ができるかですが、これはraccではプログラマが自由に選ぶことができます。raccは「ここに関数があったよ」とか「リテラルがあったよ」というのを教えてくれるので、その都度好きなオブジェクトを生成するという感じです。

^ Rubyで木構造を表現するには、ノードごとにクラスを作っても良いですけど、もっと簡単な方法として、ネストしたArrayで表現するという方法があります。

---

## bin/ore_script

```rb
#!/usr/bin/env ruby
require 'ore_script'

# 1. Parse
tree = OreScript::Parser.new.parse(ARGF.read)
p tree
```

^ この時点での実行ファイルです。

---

## 3. OreScript::Evaluator

- Walk the tree and do what is expected
 `[:if, cond_expr, then_exprs, else_exprs]`

```
    def eval_if(env, cond_expr, then_exprs, else_exprs)
      cond = eval_expression(env, cond_expr)
      case cond
      when Value::TRUE
        eval_expressions(env, then_exprs)
      when Value::FALSE
        eval_expressions(env, else_exprs)
      else
        raise "must not happen"
      end
    end
```

^ パースができたら、次はプログラムを実行する部分(エバリュエータ)を作りましょう。ここは本題ではないのではしょりますが、木構造を上から順にたどって、ノードごとに決められた動作を行います。例えばif式を見つけたら、ifの条件の部分を実行して、結果がTRUEだったらthenの部分を実行して...みたいなことをします。

---

## bin/ore_script

```rb
#!/usr/bin/env ruby
require 'ore_script'

# 1. Parse
tree = OreScript::Parser.new.parse(ARGF.read)
# 3. Execute
OreScript::Evaluator.new.eval(tree)
```

^ この時点の実行ファイルです。

---

## What happens if ...

```
f = fn(x){ add(x, 1) }
f(true)   // !?
```

- Where's type inference?
- Why we wanted type inference
  - "Want to **check types** without type anottations"

^ さて実行はできましたが、このままだとこのようなプログラムが実行時エラーになってしまいます。というか型推論の話はどこにいってしまったのでしょうか？

^ ここで、もともとの目的を思い出して下さい。型推論があると、型を書かずに型チェックができるので良い、という話でした。つまり型を推論するのが目的ではなくて、静的な型チェックがやりたいのでした。ということで型チェックを追加しましょう。

---

## 2. OreScript::TypeCheck

```rb
#!/usr/bin/env ruby
require 'ore_script'

# 1. Parse
tree = OreScript::Parser.new.parse(ARGF.read)
# 2. Type Check (Type Inference here)
OreScript::TypeCheck.new.check(tree)
# 3. Execute
OreScript::Evaluator.new.eval(tree)
```

^ これがステップ2になります。

---

## Type Inference = Type Check

```
f = fn(x){ is_odd(x) }
f(true)   // !?
```

- `f :: (1) → (2)`
  `x :: (1)`
  `is_odd :: Number → Bool`
- Bool == (1)
  (1) == Number
  (2) == Bool
- ∴ Bool == Number  // !?

^ 型チェックと型推論は、どのような関係なのでしょうか。先ほどのプログラムに対して型推論アルゴリズムを適用してみると、こんな風に、途中でBool = Numberのような矛盾した式が出てきます。これによってエラーがあることがわかるんですね。

---

## Type Inference = Type Check

- Infer type before executing program
- If program has an error:
  - Bool == Number (unsatisfiable)
- Otherwise:
  - The program has consistent types
    (No contradiction detected)

^ OreScriptでは、プログラムの実行前に型推論を行います。プログラムにエラーがあると、矛盾した式が出てきます。もし型推論が無事に終了したら、プログラムの各部分に一貫性のある型が付いたということなので、型チェックが成功したことがわかります。 

---

## RECAP

- bin/ore_script
  - 1. Parse
  - 2. Type check (= Type inference)
  - 3. Execute

^ ここまでのまとめです。OreScriptの処理系では、最初にパーサを使ってソースコードを構文木に変換します。次に型推論を行うことで、型エラーがないか検査し、大丈夫なら実行します。

---

## Implementation of type inference


^ ではここからは、型推論部分の実装を少しだけ見ていきます。

---

## Three classes for type

- Type::TyRaw 
    - A type already known (Number, Bool, etc.)
    - `99 :: #<TyRaw "Number">`
- Type::TyFun 
    - Function type
    - `f :: #<TyFun #<TyRaw "Number"> -> #<TyRaw "Bool">>`
- Type::TyVar 
    - A type not yet known
    - `x :: #<TyVar (1)>`
    - `f :: #<TyVar (2)>`

^ 型について3つのクラスを用意します。1つめはTyRaw。これはNumber型、Bool型などの組み込みの型を表します。例えば99という数値リテラルがあった場合、これは明らかにNumber型だと分かります。

^ 2つめのTyFunは関数を表す型で、引数の型と返り値の型を持っています。

^ 3つめはTyVarで、これは「まだ分かってない型」という意味です。TyVarは1番、2番などの番号を持っています。TyVarは方程式を解いていく過程で、最終的に、TyRawかTyFunに置き換えられます。

---

## Three steps (recap)

1. Assume types
2. Extract type equations
3. Resolve equations

^ HM型推論の手順は3つのステップがあるのでした。型がわからないところに番号を付ける。型が同じでないといけない箇所を列挙する。最後に方程式を解く。

---

## *Actual* steps

- 1. Assume types
  - 2. Extract type equations
      - 3. Resolve equations
  - 2. Extract type equations
  - 3. Resolve equations
- ...

^ そう言ったんですが、実際の実装では、方程式を全部列挙するのではなくて、方程式を立てて、マージして、立てて、マージして...みたいにやります。

^ 理由はいくつかあります。例えばそのほうが効率がよいとか、またエラーメッセージを親切にできるとか。

---

## OreScript::TypeCheck#infer

```rb
    def infer(env, node)
      ...
    end
```

```rb
tree = Parser.new.parse("99")
infer(..., tree)
#=> [...>, Ty(Number)]

tree = Parser.new.parse("f = fn(x){ add(x)(1) }"))
infer(..., tree)
#=> [..., Ty(Number -> Number)]
```

^ TypeCheckクラスにはinferというメソッドがあって、これが型推論の本体です。こいつに構文木を食わせると、型を推論して結果を返してくれます。

---

## OreScript::TypeCheck#infer

```rb
    def infer(env, node)
      ...
      when :fcall
        ...
        result_type = TyVar.new
        s1, func_type = infer(env, func_expr)
        s2, arg_type = infer(env.substitute(s1), arg_expr)
        ...
        equation = Equation.new(
          func_type,
          TyFun.new(arg_type, result_type)
        )
        ...
    end
```

^ 例えば関数呼び出しの型を求める部分はこんな感じです。

---

## `TypeCheck.unify(*equations)`

- Pop one from `equations`
  - `#<TyFun ty1 -> ty2>` == `#<TyFun ty3 -> ty4>`
      - ty1 == ty3 
      - ty2 == ty4 
  - `#<TyRaw "Number">` == `#<TyRaw "Number">`
      - just ignore 
  - `#<TyVar (1)>` == `#<TyRaw "Number">`
      - Add `(1) == "Number"` to the answers 
      - Replace `(1)` with `#<TyRaw "Number">` in rest of the `equations`
- Repeat until all equations are removed

^ 等式をまとめるところはこんな感じです。

---

## Further topics

^ さて、本編は以上で終わりですが、おまけとして、より高度なトピックについて触れておきたいと思います。もしこのセッションを聞いて型推論についてもっと調べてみようという人がいたら、必ず「let多相」という単語に出くわすと思います。ここではそれらについて触りだけ解説します。

---

## Downside of static type check

- May reject "valid" program

```js
id = fn(x){ x }
id(99)     //→ 99
id(true)   //→ true??
```

^ ここまでの範囲だと、動きそうだけど通らないプログラムというのが存在します。例えばid関数は数値にもブールにも使えそうですが、ここまでの範囲の実装だと最初に数値を渡したところでidは数値をとる関数だと推論されてしまうので、ブールを渡そうとするとエラーになってしまいます。

---

## let

```
let id = fn(x){ x } in
  id(99)
  id(true) 
```

^ もとの論文では、letというキーワードがあって、letで関数を定義した場合は、その関数をいろんな型として使えるという仕組みがあります。

---

## let-poly branch[^2]

```
id = fn(x){ x }    // id :: ∀(1). (1) → (1)
id(99)                
id(true) 
```

[^2]: [https://github.com/yhara/rk2015orescript/tree/let-poly](https://github.com/yhara/rk2015orescript/tree/let-poly)

^ もとの論文では、letというキーワードがあって、letで関数を定義した場合は、その関数をいろんな型として使えるという仕組みがあります。

---

## let-poly branch[^2]

```
id = fn(x){ x }    // id :: ∀(1). (1) → (1)
id(99)             // ←id here :: (2) → (2)
id(true)           // ←id here :: (3) → (3)
```

[^2]: [https://github.com/yhara/rk2015orescript/tree/let-poly](https://github.com/yhara/rk2015orescript/tree/let-poly)

---

## Acknowledgements

- 『Types And Programming Language』(TAPL)
  - Japanese edition: [『型システム入門』](http://www.amazon.co.jp/gp/product/4274069117/ref=as_li_tf_tl?ie=UTF8&camp=247&creative=1211&creativeASIN=4274069117&linkCode=as2&tag=yharaharay-22")
- [『プログラミング言語の基礎概念』](http://www.amazon.co.jp/gp/product/4781912850/ref=as_li_tf_tl?ie=UTF8&camp=247&creative=1211&creativeASIN=4781912850&linkCode=as2&tag=yharaharay-22)
  - [see also(PDF)](http://www.fos.kuis.kyoto-u.ac.jp/~t-sekiym/classes/isle4/OCaml-meeting0908-revised.pdf)
- [『プログラミング言語の基礎理論』](http://www.amazon.co.jp/gp/product/4320026594/ref=as_li_tf_tl?ie=UTF8&camp=247&creative=1211&creativeASIN=4320026594&linkCode=as2&tag=yharaharay-22)(絶版)
- [『アルゴリズムW入門』](https://github.com/pi8027/typeinfer) (同人誌)
- 『Scala By Example』[chapter16](http://www29.atwiki.jp/tmiya/pages/78.html)
- [Ibis](http://d.hatena.ne.jp/takuto_h/20110401/impl) (Type infrence written in JavaScript)

^ 実はOreScriptもこの機能が実装済みなのですが、解説が大変なので、詳しく知りたい人は頑張って本を読んで下さい。

---

## Summary

- OreScript
  - Small language with type inference
  - Type check without type annotation
- Type inference (= type check)
  - Build type equeations
  - Resolve type equeations
- [https://github.com/yhara/rk2015orescript](https://github.com/yhara/rk2015orescript)

^ まとめです。本セッションではOreScriptという、型推論を備えた小さな言語を作りました。OreScriptでは型をプログラマが書くことなしに、型チェックができています。

^ で、型推論は型チェックも兼ねていることと、「型が同じであるべき部分を列挙して、それらを満たすような型を求める」という手順を説明しました。

^ 実装はこのURLにpushしてあるので、何かの参考になれば幸いです。ご清聴ありがとうございました。
