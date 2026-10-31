# frozen_string_literal: true

module Raindown
  module TUI
    # How much a method envies another class, the fifth temper beside woe, frolic, dread and malice: from 0 to 9, which is
    # how its evidence ranks among the project's, the class it envies, and why, in a few words. It's envious when its evidence is
    # clear on its own, and it ranks near the top, so a tidy project has none.
    Envy = Data.define(:score, :evidence, :home, :reason) do
      def envious? = evidence >= Envies::CLEAR && score >= Envies::ENVIOUS

      # What Claude Code is told, to move it where it belongs.
      def prompt = "It #{reason}, so consider moving it to #{home}."
    end

    # Finds envy among a project's methods, in any language, by their code's words rather than its grammar. Envy is
    # the most telling: a method that calls a parameter or variable named after another class, like order.total and
    # order.items for Order, at least one of them a method Order has, much more than it touches its own class, like self.,
    # this., @ivars and its siblings, the methods of its class in the same file. Being named after another class it uses,
    # being a loner that calls no sibling, and no sibling calls, and being in a class not named after its file, in a file
    # with one that is, add to it. Functions outside a class have no class of their own, so they never envy.
    module Envies
      # The calls on another class's receiver that make envy, as long as there are ENVY_RATIO times as many as on itself.
      ENVY_CALLS = 3
      ENVY_RATIO = 3
      # The most evidence envy gives, and what the rest each give.
      ENVY_MOST = 6
      NAMED = 2
      LONER = 1
      LOST = 1
      # The evidence that's clear on its own, and the score it needs too, so only the clearest are envious.
      CLEAR = 4
      ENVIOUS = 7
      # Owners with shorter names, like UI, are left out of what methods are named after, as they're in too many words.
      NAME_LENGTH = 4
      # The names a method calls itself by, like self.total or this.total.
      SELVES = %w[self this cls].freeze
      # Strings, and comments on their own lines or after code, which aren't code to count.
      STRING = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`/
      COMMENT = %r{\A\s*(?:#|//|/?\*|--).*|\s(?:#|//)\s.*}
      # A call on a receiver, like order.total, order&.total, order?.total or $order->total, with the receiver and member.
      RECEIVER = /(?<![\w.$@:>])\$?([a-z_]\w*)\s*(?:&\.|\?\.|\.|->)\s*([A-Za-z_]\w*[?!]?)/
      # A bare word, which may be a call to a sibling, but not a member of something else, like order.total's total.
      WORD = /(?<![\w.$@:>])[A-Za-z_]\w*[?!]?/
      # An instance variable, like @total, but not @@total, or an email.
      IVAR = /(?<![\w@])@([a-z_]\w*)/
      # A Go method's receiver, like s in func (s *Square) Area(), which is its self.
      GO_RECEIVER = /\A\s*func\s*\(\s*(\w+)/
      # Where a method's parameters and variables are declared: its first parentheses, a block's or a lambda's
      # parameters, an assignment, or a loop's or the like's variable.
      DECLARED = [/\A[^(\n]*\(([^)]*)\)/, /\|([^|]*)\|/, /\(([^()]*)\)\s*=>/, /(\w+)\s*=>/, /(?<![\w.@$])(\w+)\s*(?:=(?![=~>])|:=)/,
                  /\b(?:let|const|var|for|as)\s+(\w+)/].freeze

      # What a method's code says about its class: the members called on each of its parameters and variables, how many
      # times it touches itself, how many times it says each bare word, which includes its siblings it calls, and the
      # words it says at all, squashed, to tell which classes it uses.
      Body = Data.define(:receivers, :own, :calls, :mentions)

      # The project's methods' bodies, its owners, each one's method names, each class's methods, by file and owner, and
      # each file's owners.
      Project = Data.define(:bodies, :owners, :classes, :files) do
        def self.of(methods)
          owned = methods.select(&:owner)
          new(bodies: methods.to_h { [it, Envies.body(it)] },
              owners: owned.group_by(&:owner).transform_values { it.to_set(&:name) },
              classes: owned.group_by { [it.path, it.owner] }, files: owned.group_by(&:path).transform_values { it.map(&:owner).uniq })
        end

        def siblings(method) = classes.fetch([method.path, method.owner], []) - [method]

        # How many times it touches its own class: itself, its instance variables and its siblings.
        def own(method) = bodies[method].own + siblings(method).sum { bodies[method].calls[it.name] }

        # Whether it keeps to itself, touching nothing of its class, while none of its siblings call it.
        def loner?(method) = own(method).zero? && siblings(method).none? { bodies[it].calls[method.name].positive? }
      end

      module_function

      # Each method with its Envy, from 0 for no evidence to 9 for the most, where the same evidence scores the same.
      def envying(methods)
        project = Project.of(methods)
        found = methods.to_h { [it, evidence(it, project)] }
        ranked = found.values.map(&:first).sort
        methods.map do |method|
          points, home, reason = found[method]
          score = ranked.bsearch_index { it >= points } * 9 / [ranked.length - 1, 1].max
          method.with(envy: Envy.new(score:, evidence: points, home:, reason:))
        end
      end

      # The method's evidence, the class it probably belongs to, and why, or none for a function outside a class.
      def evidence(method, project)
        return [0, nil, nil] unless method.owner

        own = project.own(method)
        envy = envy(method, project.bodies[method], own, project.owners)
        named = named_after(method, project.bodies[method], own, project.owners)
        points = [envy.first, (NAMED if named), (LONER if project.loner?(method)), (LOST if lost?(method, project.files))]
        [points.compact.sum, *why(envy, named, own)]
      end

      # Points for working with another class's receiver much more than with its own class, with that class, the receiver
      # and how many calls there were on it, or no points.
      def envy(method, body, own, owners)
        home, receiver, calls = body.receivers.filter_map { |name, members| envied(name, members, method, owners) }.max_by(&:last)
        return [0] unless home && calls >= ENVY_CALLS && own * ENVY_RATIO <= calls

        [[calls, ENVY_MOST].min, home, receiver, calls]
      end

      # The other class a receiver's named after, with how many calls there are on it, when one of them is that class's.
      def envied(receiver, members, method, owners)
        home = owner_named(receiver, owners)
        return unless home && home != method.owner && members.intersect?(owners[home].to_a)

        [home, receiver, members.length]
      end

      # The class it probably belongs to, and why, from its envy, or else what it's named after.
      def why(envy, named, own)
        _points, home, receiver, calls = envy
        return [home, "envies #{home}: #{calls} calls on #{receiver}, #{own} on self"] if home
        return [named, "envies #{named}: it's named after it, and makes #{own} calls on self"] if named

        [nil, nil]
      end

      # The longest other owner whose words are in the method's name, among others, like Invoice in format_invoice, when
      # it uses it, and hardly uses its own class.
      def named_after(method, body, own, owners)
        return if own > 1

        name = words(method.name)
        owners.each_key.select { named_in?(it, name, method.owner) && body.mentions.include?(squashed(it)) }.max_by(&:length)
      end

      def named_in?(owner, name, own_owner)
        owner_words = words(owner)
        owner != own_owner && owner.length >= NAME_LENGTH && name.length > owner_words.length &&
          name.each_cons(owner_words.length).include?(owner_words)
      end

      # In a class not named after its file, when another class in the file is, like Parser beside CLI in cli.rb.
      def lost?(method, files)
        file = squashed(File.basename(method.path, '.*'))
        !named_like?(method.owner, file) && files.fetch(method.path, []).any? { named_like?(it, file) }
      end

      # Whether the owner's named after the file, allowing for a plural or a suffix, like CodeMethod in code_methods.rb.
      def named_like?(owner, file)
        owner = squashed(owner)
        file.start_with?(owner) || owner.start_with?(file)
      end

      # The owner a receiver's named after, like Order for order, or OrderItem for order_item or orderItem.
      def owner_named(receiver, owners) = owners.each_key.find { squashed(it) == squashed(receiver) }

      # What the method's code says.
      def body(method)
        code = code(method)
        selves = [*SELVES, method.lines.first.to_s[GO_RECEIVER, 1]].compact
        receivers = code.scan(RECEIVER).group_by(&:first).transform_values { it.map(&:last) }
        Body.new(receivers: receivers.slice(*declared(code)), own: own(code, receivers, selves), calls: calls(code, receivers, selves),
                 mentions: mentions(code, receivers))
      end

      # How many times it touches itself, like self.total, or its instance variables.
      def own(code, receivers, selves) = selves.sum { receivers.fetch(it, []).length } + code.scan(IVAR).length

      # The words it says at all, squashed, like order for order.total, or @order.
      def mentions(code, receivers) = [*code.scan(WORD), *receivers.keys, *code.scan(IVAR).flatten].to_set { squashed(it) }

      # The method's code, without its strings and comments, or the start of its first line, up to its name.
      def code(method)
        first, *rest = method.lines
        [first.to_s.sub(CodeMethods::DEFINITION, ''), *rest].map { it.gsub(STRING, '""').sub(COMMENT, '') }.join("\n")
      end

      # The parameters and variables the code declares, which are what envy counts, rather than calls on itself, like
      # Ruby's bare attribute readers.
      def declared(code) = DECLARED.flat_map { code.scan(it).flatten }.flat_map { it.to_s.scan(/[a-z_]\w*/) }.uniq - SELVES

      # How many times it says each bare word, or calls it on itself, like self.total.
      def calls(code, receivers, selves)
        tally = Hash.new(0).merge(code.scan(WORD).tally)
        selves.each { |name| receivers.fetch(name, []).each { tally[it] += 1 } }
        tally
      end

      # The words in a name, in snake_case or camelCase, like format and invoice.
      def words(name) = name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.split(/[^a-z\d]+/).reject(&:empty?)

      def squashed(name) = name.downcase.delete('_$@-')
    end
  end
end
