module RBS
  module Inline
    module AST
      class Tree
        # @rbs! type token = [Symbol, String]
        # @rbs! type tree = token | Tree | Types::t | MethodType | nil

        attr_reader :trees #:: Array[tree]
        attr_reader :type #:: Symbol
        attr_reader :non_trivia_trees #:: Array[tree]

        # @rbs type: Symbol
        def initialize(type) #:: void
          @type = type
          @trees = []
          @non_trivia_trees = []
        end

        # @rbs tok: tree
        def <<(tok) #:: self
          trees << tok
          unless tok.is_a?(Array) && tok[0] == :tWHITESPACE
            non_trivia_trees << tok
          end
          self
        end

        def to_s #:: String
          buf = +""

          trees.each do |tree|
            case tree
            when Array
              buf << tree[1]
            when Tree
              buf << tree.to_s
            when nil
            else
              loc = tree.location or raise
              buf << loc.source
            end
          end

          buf
        end

        # Returns n-th token from the children
        #
        # Raises if the value is not a token nor `nil`.
        #
        # @rbs index: Integer
        def nth_token(index) #:: token?
          tok = non_trivia_trees[index]
          case tok
          when Array, nil
            tok
          else
            raise
          end
        end

        # Returns n-th token from the children
        #
        # Returns `nil` if the value is not a token.
        #
        # @rbs index: Integer
        # @rbs returns token?
        def nth_token?(index)
          tok = non_trivia_trees[index]
          case tok
          when Array
            tok
          else
            nil
          end
        end

        # Returns n-th token from the children
        #
        # Raises if the value is not a token.
        #
        # @rbs index: Integer
        # @rbs returns token
        def nth_token!(index)
          nth_token(index) || raise
        end

        # Returns n-th tree (or `nil`) from the children
        #
        # Raises when the element is not a Tree nor `nil`.
        #
        # @rbs index: Integer
        # @rbs returns Tree? -- `Tree` object or `nil`
        def nth_tree(index)
          tok = non_trivia_trees[index]
          case tok
          when Tree, nil
            tok
          else
            raise
          end
        end

        # Returns n-th tree (or `nil`) from the children
        #
        # @rbs index: Integer
        # @rbs returns Tree? -- `Tree` object, or `nil` otherwise
        def nth_tree?(index)
          tok = non_trivia_trees[index]
          case tok
          when Tree
            tok
          else
            nil
          end
        end

        # Returns n-th tree from the children
        #
        # Raises if the value is not a Tree.
        #
        # @rbs index: Integer
        # @rbs returns Tree -- `Tree` object
        def nth_tree!(index)
          nth_tree(index) || raise
        end

        def nth_type(index)
          tok = non_trivia_trees[index]
          case tok
          when Array, Tree, MethodType
            raise
          else
            tok
          end
        end

        def nth_type?(index)
          tok = non_trivia_trees[index]
          case tok
          when Array, Tree, nil, MethodType
            nil
          else
            tok
          end
        end

        def nth_type!(index)
          nth_type(index) || raise
        end

        def nth_method_type(index)
          tok = non_trivia_trees[index]
          case tok
          when MethodType, nil
            tok
          else
            raise
          end
        end

        def nth_method_type?(index)
          tok = non_trivia_trees[index]
          case tok
          when MethodType
            tok
          else
            nil
          end
        end

        def nth_method_type!(index)
          nth_method_type(index) || raise
        end
      end
    end
  end
end
