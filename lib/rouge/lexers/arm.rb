# -*- coding: utf-8 -*- #

module Rouge
  module Lexers
    class ARM < RegexLexer
      tag 'arm'
      title "ARM"
      desc "ARMv7 Assembly"

      filenames '*.S'
      mimetypes 'text/x-assembly'
      
      require 'yaml'
      @@mnemonics = ::Set.new(
        ::YAML.load(
          File.read(Pathname.new(__FILE__).dirname.join('arm/armv7_instructions.yaml'))
        )
      )
      
      state :root do
        rule /\.\S+:\s*\n/, Name::Label
        rule /\S+:\s*\n/, Name::Label
        rule /\.[^\s:]+/, Comment::Preproc, :directive
        rule /([a-zA-Z])\S+/ do |m|
          name = m[0].downcase
          if @@mnemonics.include? name
            token Keyword::Reserved
            push :mnemonic
          else
            token Keyword::Variable
            push :directive
          end
        end
        rule /(\n|\r|\r\n)/, Text::Whitespace
        mixin :whitespace
      end
      
      state :whitespace do
        rule %r<(;|//).*>, Comment::Single
        rule /[ \t]+/, Text::Whitespace
      end
      
      state :pop_on_newline do
        rule /(\n|\r|\r\n)/, Text::Whitespace, :pop!
      end
      
      state :mnemonic do
        mixin :whitespace
        mixin :pop_on_newline
        rule /([rdsq]\d+|pc|sp)/i, Keyword::Reserved
        rule /,/, Punctuation
        rule /#\d+/, Num
        rule /#\S+[^\]\)]/, Num::Other
        rule /:\S+/, Name::Label
        rule /\S+/, Keyword::Variable
      end
      
      state :directive do
        mixin :whitespace
        mixin :pop_on_newline
        rule /\d+/, Num
        rule /('.*'|".*")/, Str
        rule /,/, Punctuation
        rule /\S+/, Other
      end
      
    end
  end
end

