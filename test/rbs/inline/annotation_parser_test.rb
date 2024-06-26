# frozen_string_literal: true

require "test_helper"

class RBS::Inline::AnnotationParserTest < Minitest::Test
  include RBS::Inline

  def parse_comments(src)
    Prism.parse_comments(src, filepath: "a.rb")
  end

  def test_lvar_decl_annotation
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs size: Integer -- size of something
      # @rbs keyword: Symbol
      # @rbs block
      # @rbs x -- Hello world
      # @rbs y: Array[
      # @rbs z: Array[  --
      #   something
      #   More comments
      RUBY

    assert_equal 6, annots[0].annotations.size
    annots[0].annotations[0].tap do |annotation|
      assert_equal :size, annotation.name
      assert_equal "Integer", annotation.type.to_s
      assert_equal "-- size of something", annotation.comment
    end
    annots[0].annotations[1].tap do |annotation|
      assert_equal :keyword, annotation.name
      assert_equal "Symbol", annotation.type.to_s
      assert_nil annotation.comment
    end
    annots[0].annotations[2].tap do |annotation|
      assert_equal :block, annotation.name
      assert_nil annotation.type
      assert_nil annotation.comment
    end
    annots[0].annotations[3].tap do |annotation|
      assert_equal :x, annotation.name
      assert_nil annotation.type
      assert_equal "-- Hello world", annotation.comment
    end
    annots[0].annotations[4].tap do |annotation|
      assert_equal :y, annotation.name
      assert_nil annotation.type
      assert_nil annotation.comment
    end
    annots[0].annotations[5].tap do |annotation|
      assert_equal :z, annotation.name
      assert_nil annotation.type
      assert_equal "--\n  something\n  More comments", annotation.comment
    end
  end

  def test_lvar_decl_annotation__escape
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs !skip: Integer
      RUBY

    assert_equal 1, annots[0].annotations.size
    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::VarType, annotation
      assert_equal :skip, annotation.name
      assert_equal "Integer", annotation.type.to_s
    end
  end

  def test_return_type_annotation
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs returns Integer -- size of something
      # @rbs returns Symbol
      # @rbs returns
      # @rbs returns Array[
      # @rbs returns Array[  -- something
      RUBY

    assert_equal 5, annots[0].annotations.size
    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::ReturnType, annotation
      assert_equal "Integer", annotation.type.to_s
      assert_equal "-- size of something", annotation.comment
    end
    annots[0].annotations[1].tap do |annotation|
      assert_instance_of AST::Annotations::ReturnType, annotation
      assert_equal "Symbol", annotation.type.to_s
      assert_nil annotation.comment
    end
    annots[0].annotations[2].tap do |annotation|
      assert_instance_of AST::Annotations::ReturnType, annotation
      assert_nil annotation.type
      assert_nil annotation.comment
    end
    annots[0].annotations[3].tap do |annotation|
      assert_instance_of AST::Annotations::ReturnType, annotation
      assert_nil annotation.type
      assert_nil annotation.comment
    end
    annots[0].annotations[4].tap do |annotation|
      assert_instance_of AST::Annotations::ReturnType, annotation
      assert_nil annotation.type
      assert_equal "-- something", annotation.comment
    end
  end

  def test_type_assertion
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      #:: (String) -> void
      #:: [Integer, String]
      #:: [Integer
      #:: (
      #    String,
      #    Integer,
      #   ) -> void
      # :: String
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_equal "(String) -> void", annotation.type.to_s
    end
    annots[0].annotations[1].tap do |annotation|
      assert_equal "[ Integer, String ]", annotation.type.to_s
    end
    annots[0].annotations[2].tap do |annotation|
      assert_nil annotation.type
    end
    annots[0].annotations[3].tap do |annotation|
      assert_equal "(String, Integer) -> void", annotation.type.to_s
    end
    annots[0].annotations[4].tap do |annotation|
      assert_nil annotation
    end
  end

  def test_type_application
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      #[String, Integer]
      #[String[
      #[]
      # [String]
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_equal ["String", "Integer"], annotation.types.map(&:to_s)
    end
    annots[0].annotations[1].tap do |annotation|
      assert_nil annotation.types
    end
    annots[0].annotations[2].tap do |annotation|
      assert_nil annotation.types
    end
    annots[0].annotations[3].tap do |annotation|
      assert_nil annotation
    end
  end

  def test_annotation
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs %a{pure} %a[hello] %a(world)
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_equal ["%a{pure}", "%a[hello]", "%a(world)"], annotation.contents
    end
  end

  def test_skip
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs skip
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::Skip, annotation
    end
  end

  def test_inherits
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs inherits Object
      # @rbs inherits Array[String]
      # @rbs inherits
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_equal TypeName("Object"), annotation.super_name
      assert_equal [], annotation.args.map(&:to_s)
    end
    annots[0].annotations[1].tap do |annotation|
      assert_equal TypeName("Array"), annotation.super_name
      assert_equal ["String"], annotation.args.map(&:to_s)
    end
    annots[0].annotations[2].tap do |annotation|
      assert_nil annotation.super_name
      assert_nil annotation.args
    end
  end

  def test_attributes_typed_annotation
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
        attr_reader :foo #:: Foo
        attr_reader :bar #:: Bar
      RUBY

    assert_equal 2, annots.size
    assert_equal ":: Foo", annots[0].content
    assert_equal ":: Bar", annots[1].content
  end

  def test_override
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs override
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::Override, annotation
    end
  end

  def test_use
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs use ::Foo
      # @rbs use Foo
      # @rbs use Foo::Bar
      # @rbs use Foo::bar
      # @rbs use Foo::_Bar
      # @rbs use Foo::*
      # @rbs use Foo::Bar as Bar2, Foo::bar as bar2, Foo::_Bar as _Bar2
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::Use, annotation

      annotation.clauses[0].tap do |clause|
        assert_equal TypeName("::Foo"), clause.type_name
        assert_nil clause.new_name
      end
    end
    annots[0].annotations[1].tap do |annotation|
      assert_instance_of AST::Annotations::Use, annotation

      annotation.clauses[0].tap do |clause|
        assert_equal TypeName("Foo"), clause.type_name
        assert_nil clause.new_name
      end
    end
    annots[0].annotations[2].tap do |annotation|
      assert_instance_of AST::Annotations::Use, annotation

      annotation.clauses[0].tap do |clause|
        assert_equal TypeName("Foo::Bar"), clause.type_name
        assert_nil clause.new_name
      end
    end
    annots[0].annotations[3].tap do |annotation|
      assert_instance_of AST::Annotations::Use, annotation

      annotation.clauses[0].tap do |clause|
        assert_equal TypeName("Foo::bar"), clause.type_name
        assert_nil clause.new_name
      end
    end
    annots[0].annotations[4].tap do |annotation|
      assert_instance_of AST::Annotations::Use, annotation

      annotation.clauses[0].tap do |clause|
        assert_equal TypeName("Foo::_Bar"), clause.type_name
        assert_nil clause.new_name
      end
    end
    annots[0].annotations[5].tap do |annotation|
      assert_instance_of AST::Annotations::Use, annotation

      annotation.clauses[0].tap do |clause|
        assert_equal Namespace("Foo::"), clause.namespace
      end
    end
    annots[0].annotations[6].tap do |annotation|
      assert_instance_of AST::Annotations::Use, annotation

      annotation.clauses[0].tap do |clause|
        assert_equal TypeName("Foo::Bar"), clause.type_name
        assert_equal :Bar2, clause.new_name
      end
      annotation.clauses[1].tap do |clause|
        assert_equal TypeName("Foo::bar"), clause.type_name
        assert_equal :bar2, clause.new_name
      end
      annotation.clauses[2].tap do |clause|
        assert_equal TypeName("Foo::_Bar"), clause.type_name
        assert_equal :_Bar2, clause.new_name
      end
    end
  end

  def test_module_self
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
        # @rbs module-self BasicObject
        # @rbs module-self _Each[String] -- consume something
        # @rbs module-self top
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::ModuleSelf, annotation
      assert_equal "BasicObject", annotation.constraint.to_s
      assert_nil annotation.comment
    end

    annots[0].annotations[1].tap do |annotation|
      assert_instance_of AST::Annotations::ModuleSelf, annotation
      assert_equal "_Each[String]", annotation.constraint.to_s
      assert_equal "-- consume something", annotation.comment
    end

    annots[0].annotations[2].tap do |annotation|
      assert_instance_of AST::Annotations::ModuleSelf, annotation
      assert_nil annotation.constraint
      assert_nil annotation.comment
    end
  end

  def test_generic
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
        # @rbs generic X
        # @rbs generic unchecked in Y < String -- Comment
      RUBY

    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::Generic, annotation

      assert_equal :X, annotation.type_param.name
      assert_equal :invariant, annotation.type_param.variance
      refute_predicate annotation.type_param, :unchecked?
      assert_nil annotation.type_param.upper_bound
      assert_nil annotation.comment
    end
    annots[0].annotations[1].tap do |annotation|
      assert_instance_of AST::Annotations::Generic, annotation

      assert_equal :Y, annotation.type_param.name
      assert_equal :contravariant, annotation.type_param.variance
      assert_predicate annotation.type_param, :unchecked?
      assert_equal "String", annotation.type_param.upper_bound.to_s
      assert_equal "-- Comment", annotation.comment
    end
  end

  def test_ivar_decl_annotation
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs @size: Integer -- size of something
      # @rbs self.@block: String
      # @rbs @y: Array[
      RUBY

    assert_equal 3, annots[0].annotations.size
    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::IvarType, annotation
      assert_equal :@size, annotation.name
      refute_predicate annotation, :class_instance
      assert_equal "Integer", annotation.type.to_s
      assert_equal "-- size of something", annotation.comment
    end
    annots[0].annotations[1].tap do |annotation|
      assert_instance_of AST::Annotations::IvarType, annotation
      assert_equal :@block, annotation.name
      assert_predicate annotation, :class_instance
      assert_equal "String", annotation.type.to_s
      assert_nil annotation.comment
    end
    annots[0].annotations[2].tap do |annotation|
      assert_instance_of AST::Annotations::IvarType, annotation
      assert_equal :@y, annotation.name
      assert_nil annotation.type
      assert_nil annotation.comment
    end
  end

  def test_yields_annotation
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
        # @rbs yields () [self: String] -> Integer -- Some comments here
        # @rbs yields () [self: S -- Another comment
        # @rbs yields -- Another comment
        # @rbs yields [optional] () -> void
        # @rbs yields [optional]
      RUBY

    assert_equal 5, annots[0].annotations.size
    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::Yields, annotation
      assert_instance_of RBS::Types::Block, annotation.block_type
      refute annotation.optional
      assert_equal "-- Some comments here", annotation.comment
    end
    annots[0].annotations[1].tap do |annotation|
      assert_instance_of AST::Annotations::Yields, annotation
      assert_equal "() [self: S ", annotation.block_type
      refute annotation.optional
      assert_equal "-- Another comment", annotation.comment
    end
    annots[0].annotations[2].tap do |annotation|
      assert_instance_of AST::Annotations::Yields, annotation
      assert_nil annotation.block_type
      refute annotation.optional
      assert_equal "-- Another comment", annotation.comment
    end
    annots[0].annotations[3].tap do |annotation|
      assert_instance_of AST::Annotations::Yields, annotation
      assert_instance_of RBS::Types::Block, annotation.block_type
      assert annotation.optional
      assert_nil annotation.comment
    end
    annots[0].annotations[4].tap do |annotation|
      assert_instance_of AST::Annotations::Yields, annotation
      assert_nil annotation.block_type
      assert annotation.optional
      assert_nil annotation.comment
    end
  end

  def test_embedded_annotation
    annots = AnnotationParser.parse(parse_comments(<<~RUBY))
      # @rbs!
      #   type t = Integer | String
    RUBY

    assert_equal 1, annots[0].annotations.size
    annots[0].annotations[0].tap do |annotation|
      assert_instance_of AST::Annotations::Embedded, annotation
      assert_equal "\n  type t = Integer | String", annotation.content
    end
  end
end
