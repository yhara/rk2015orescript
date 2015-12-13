OreScript
=========

Tiny language with Hindley-Milner type inference.

Presentaion
-----------

* http://rubykaigi.org/2015/presentations/yhara
* https://speakerdeck.com/yhara/lets-make-a-functional-language
* [.md](slide/yhara_functional_rev4.md)

How to run
----------

    $ bundle install
    $ ./bin/ore_script examples/hello.ore
    $ ./bin/ore_script -h
    $ ./bin/ore_script -satv examples/hello.ore

Run test
--------

    $ bundle install
    $ bundle exec rspec

Branches
--------

- master
  - As simple as possible
- let-poly
  - Supports Let-polymorphism
- multi-arg
  - Supports functions with multiple arguments
  - Supports if-expression
