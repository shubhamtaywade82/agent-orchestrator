# frozen_string_literal: true

require "parser/ruby33"

module Ares
  module ContextEngine
    class AstExtractor
      def extract(file)
        code = File.read(file)
        Parser::Ruby33.parse(code)
      end

      def extract_symbols(file)
        ast = extract(file)
        return {} if ast.nil?

        Visitor.new.visit(ast).merge(file: file)
      end

      class Visitor
        def visit(node)
          return {} if node.nil?

          case node.type
          when :class, :module
            visit_class_or_module(node)
          when :def
            { methods: [node.children[0].to_s] }
          when :const
            visit_const(node)
          else
            visit_children(node)
          end
        end

        private

        def visit_class_or_module(node)
          name = const_name(node.children[0])
          body = node.children[2]
          out = { classes: [name].compact, methods: [], constants: [], dependencies: [] }
          out = merge_into(out, visit_children(body)) if body
          out[:classes] = [out[:classes].last] if out[:classes].size > 1
          out
        end

        def visit_const(node)
          { constants: [const_name(node)], dependencies: [const_name(node)] }
        end

        def const_name(node)
          return nil unless node && node.type == :const

          base = node.children[0]
          leaf = node.children[1].to_s
          base ? "#{const_name(base)}::#{leaf}" : leaf
        end

        def visit_children(node)
          return {} unless node.respond_to?(:children)

          node.children.each_with_object({}) do |child, acc|
            next unless child.is_a?(Parser::AST::Node)

            merge_into(acc, visit(child))
          end
        end

        def merge_into(acc, one)
          one.each do |k, v|
            next if v.nil? || v.empty?

            acc[k] = (acc[k] || []) + Array(v)
          end
          acc
        end
      end
    end
  end
end
