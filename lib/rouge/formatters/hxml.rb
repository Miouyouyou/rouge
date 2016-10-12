# -*- coding: utf-8 -*- #

module Rouge
  module Formatters
    # Transforms a token stream into HTML output.
    class HXML < Formatter
      tag 'hxml'

      # @yield the html output.
      def stream(tokens, &b)
        tokens.each { |tok, val| yield span(tok, val) }
      end

      def span(tok, val)
        safe_span(tok, val.gsub(/[&<>]/, TABLE_FOR_ESCAPE_HTML))
      end

      def safe_span(tok, safe_val)
        token_infos = tok.to_s.gsub("Rouge::Token::Tokens::", "").split('::')
        tag_name = token_infos.shift.downcase
        if !token_infos.empty?
          arg_list = %Q| type="#{token_infos.map(&:downcase).join(" ")}"|
        else
          arg_list = ""
        end
        "<#{tag_name}#{arg_list}>#{safe_val}</#{tag_name}>"
      end

    private
      TABLE_FOR_ESCAPE_HTML = {
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
      }
    end
  end
end
