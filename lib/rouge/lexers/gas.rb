# -*- coding: utf-8 -*- #
module Rouge
  module Lexers

    # Gnu AS is a SET of tools that assemble programs based on provided scripts.
    # These tools can work with different syntaxes.
    #
    # For example, GNU AS for Intel can parse Intel Assembly files written using
    # the Intel manuals syntax, or the AT&T syntax. Other GNU AS versions can
    # parse ARM assembly scripts written using the ARM manuals syntax, or also
    # the AT&T syntax.
    #
    # Note that Assembly is not a language per itself. Any tool that parse
    # mnemonics and arguments passed to it, and generate technically correct
    # executables is an assembler.
    # Every assembler tool has its own little syntax, its own way to define
    # metadata, data, data sections and mnenonics arguments.
    # The only part that does not change is the mnemonics, as they are defined
    # in the architecture manuals.
    #
    # Given these restrictions, this class was written with extensibility in
    # mind. However, my knowledge of Rouge is extremely limited, so I might
    # have missed a lot of opportunities to make it more easy to extend.
    class GAS < RegexLexer
      tag 'gas'
      title "GAS"
      desc <<-EOD.strip.gsub(/\s+/, ' ')
        GNU Assembler main syntax. No assembly lexer contained.
        This lexer focuses on interpreting GAS directives and data
        definitions. Mnemonics parsing is delegated.
        Additional assembly mnemonics lexers are specified with the arch and
        syntax options.
        Example arch=arm will load the arm-native lexer.
        GAS Assembly lexers are currently stored in the lib/rouge/lexers/gas
        folder.
      EOD

      filenames '*.S'
      mimetypes 'text/x-assembly'

      def initialize(opts={})
        # If you have a Lexer Class for Intel mnemonics and AT&T syntax named
        #   Intel::AT_T
        # Add it like this :
        # assembly_parsers[:"intel_at&t"] = Intel::AT_T
        # It should then be selected in the following options are passed :
        # arch = intel
        # syntax = at&t
        #
        # The Assembly Lexer Class must implement a Class method
        # 'recognise?(token)' which will be invoked on the with the first word
        # of any line that is not clearly recognised as a GNU AS directive
        # (meaning, it's ambiguous).
        #
        # If recognise?(token) returns true, the whole line parsing will be
        # delegated to your Class.
        # Else the whole line will be parsed by the Directive Lexer, which
        # parse GNU AS directives.
        #
        # A default implementation of recognise?(token) is provided by the
        # module AssemblyLexer. This implementation requires that a Class method
        # named 'mnemonics' is defined, and will call it like this :
        #   mnemonics.include?(token)
        #
        # See the ARM::Native implementation for a hint on how to use this
        # default implementation.
        assembly_parsers = Hash.new(NoASM)
        assembly_parsers[:arm_native] = ARM::Native

        architecture = opts.delete(:arch) { "arm" }
        syntax = opts.delete(:syntax) { "native" }
        @assembly_parser = assembly_parsers[:"#{architecture}_#{syntax}"]
        super(opts)
      end

      state :root do
        rule /\.\S+:\s*\n/, Name::Label
        rule /\S+:\s*\n/, Name::Label
        rule /\.[^\s:].*\n/ do |m|
          delegate Directive
        end
        rule /(\n|\r|\r\n)/, Text::Whitespace
        mixin :whitespace
        rule /(\S+).*/ do |m|
          # FIXME: I just want to check the first group of THIS REGEXP !
          #        If the assembly parser recognises the mnemonic THEN pass the
          #        whole line to the assembly parser !
          #        Else, pass it to the :directive state.
          #        However, m[0] refers to the WHOLE match, instead of the first
          #        group (\S+), and I do NOT understand how I can switch to
          #        another state and reparse the current line...
          #        So, yeah... classes everywhere and SLOW parsing ! Yaaay !
          if @assembly_parser.recognise?(m[0].strip.split(" ").first)
            delegate @assembly_parser
          else
            delegate Directive
          end
        end
      end

      # Classes ! EVERYWHERE !
      class Directive < RegexLexer

        def lex(stream, opts = {}, &b)
          $stderr.puts "[Directive] stream: #{stream}, opts: #{opts}, b: #{b.inspect}"
          super(stream, opts, &b)
        end
        state :root do
          rule %r<(;|//).*>, Comment::Single
          rule /[ \t]+/, Text::Whitespace
          rule /(\n|\r|\r\n)/, Text::Whitespace
          rule /\.\S+/, Comment::Preproc
          rule /\d+/, Num
          rule /('.*'|".*")/, Str
          rule /,/, Punctuation
          rule %r~[=<>!/*&|]~, Operator
          rule /^\S+/, Keyword::Variable
          rule /\S+/, Other
        end
      end
      state :whitespace do
        rule %r<(;|//).*>, Comment::Single
        rule /[ \t]+/, Text::Whitespace
      end

      state :directive do
        mixin :whitespace
        mixin :pop_on_newline
        rule /\d+/, Num
        rule /('.*'|".*")/, Str
        rule /,/, Punctuation
        rule %r~[=<>!/*&|]~, Operator
        rule /\S+/, Other
      end

      state :pop_on_newline do
        rule /(\n|\r|\r\n)/, Text::Whitespace, :pop!
      end


      # Assembly Lexers
      # Default Assembly Lexer that does nothing.
      class NoASM < RegexLexer
        def self.recognise?(token)
          false
        end
      end

      module AssemblyLexer
        def recognise?(token)
          p token
          mnemonics.include? token
        end
      end
      module ARM
        class Native < RegexLexer


          tag 'arm'
          title "ARM"
          desc "ARMv7 Assembly syntax"

          extend AssemblyLexer

          def self.mnemonics
            @@mnemonics ||= ::Set.new(::YAML.load(File.read(
              Pathname.new(__FILE__).dirname.join('arm/armv7_instructions.yml')
            )))
          end

          state :root do
            rule /\S+/, Name::Function, :mnemonic
          end

          state :mnemonic do
            rule %r<(;|//).*>, Comment::Single
            rule /[ \t]+/, Text::Whitespace
            rule /(\n|\r|\r\n)/, Text::Whitespace, :pop!
            # FIXME: This is currently a dumb registers parsing.
            rule /([rdsq]\d+|pc|sp)/i, Keyword::Reserved
            rule /,/, Punctuation
            rule /#\d+/, Num
            rule /#\S+[^\]\)]/, Num::Other
            rule /:\S+/, Name::Label
            rule /\S+/, Keyword::Variable
          end

        end # Class Native
      end # Module ARM

    end
  end
end
