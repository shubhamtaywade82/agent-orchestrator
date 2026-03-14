# frozen_string_literal: true

require "parser/ruby33"

module Ares
  module Context
    class AstExtractor
      def extract(file)
        code = File.read(file)

        ast = Parser::Ruby33.parse(code)

        ast
      end
    end
  end
end
