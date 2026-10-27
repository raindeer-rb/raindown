# frozen_string_literal: true

require 'json'
require 'open3'
require 'zlib'

module Raindown
  module TUI
    # A function or method in a project's code, to sort how it feels: where it is, its lines, how many commits changed
    # its file, and how much it drifts, from 0 to 9, which is how it ranks among the project's by both of them.
    CodeMethod = Data.define(:path, :owner, :name, :line, :lines, :changes, :drift) do
      # Like Layout#lines, or lines alone outside a class or the like.
      def label = [owner, name].compact.join('#')

      # A cell for every few lines, up to 8.
      def size = ((lines.length / 4) + 1).clamp(1, 8)

      # What drift ranks: long methods in files that keep changing weigh most.
      def weight = lines.length * (changes + 1)

      # Its code's checksum, which changes when its code does, but not its indent, trailing spaces or blank lines.
      def checksum = Zlib.crc32(lines.map(&:strip).reject(&:empty?).join("\n")).to_s(16)
    end

    # Every function and method in a project's code, in any language: from Universal Ctags when it's installed,
    # which knows over 100 languages, or else from how the code's indented. Specs, tests, and folders a project
    # doesn't write, like vendor, are left out.
    module CodeMethods
      SKIPPED = %w[.git spec test tests vendor tmp pkg node_modules].freeze
      # The kinds Ctags gives functions and methods, across languages.
      KINDS = %w[function method singletonMethod procedure subroutine func constructor].freeze
      # The files the indentation fallback reads, by extension.
      EXTENSIONS = %w[rb py js mjs ts tsx jsx go rs java kt swift c h cc cpp cs php ex exs lua sh scala].freeze
      MODIFIERS = '(?:(?:export|default|async|static|public|private|protected|pub(?:\(\w+\))?|override|final)\s+)*'
      # A line that starts a function, with its name, like "def area", "pub fn draw(" or "func (s *Square) Area(".
      DEFINITION = /\A\s*#{MODIFIERS}(?:def|function|fn|func|sub|proc)\s+(?:\([^)]*\)\s*)?(?:self\.)?([\w?!=]+)/
      # A line that starts a class or the like, with its name, which names the functions inside it.
      OWNER = /\A\s*#{MODIFIERS}(?:class|module|struct|impl|interface|trait|object)\s+(\w+(?:::\w+)*)/
      # A line that closes a block, at the indent of the line that opened it.
      CLOSER = /\A\s*(?:end\b|[}\])])/

      module_function

      def list(root)
        changes = file_changes(root)
        drifting((tagged(root) || indented(root)).map { it.with(changes: changes.fetch(it.path, 0)) })
      end

      # Each method with its drift, from 0 for the lightest to 9 for the heaviest, where methods that weigh the same
      # drift the same, so the digits spread out in any project, whatever its language or size.
      def drifting(methods)
        weights = methods.map(&:weight).sort
        methods.map { |method| method.with(drift: weights.bsearch_index { it >= method.weight } * 9 / [weights.length - 1, 1].max) }
      end

      # From Universal Ctags, or nil when it isn't installed, or the ctags installed is another, without JSON.
      def tagged(root)
        json, status = Open3.capture2('ctags', '--output-format=json', '--fields=+ne', '-R', '-f', '-',
                                      *SKIPPED.map { "--exclude=#{it}" }, '.', chdir: root, err: File::NULL)
        return unless status.success?

        sources = Hash.new { |hash, path| hash[path] = File.readlines(path, chomp: true) }
        json.each_line.filter_map { tag_method(root, JSON.parse(it), sources) }.sort_by { [it.path, it.line] }
      rescue SystemCallError, JSON::ParserError
        nil
      end

      def tag_method(root, tag, sources)
        return unless tag['_type'] == 'tag' && KINDS.include?(tag['kind']) && tag['end']

        path = File.join(root, tag['path'].delete_prefix('./'))
        lines = sources[path][(tag['line'] - 1)...tag['end']]
        CodeMethod.new(path:, owner: tag['scope']&.split(/\.|::/)&.last, name: tag['name'], line: tag['line'], lines:, changes: 0, drift: 0)
      end

      def indented(root)
        files(root).flat_map { indented_in(it) }
      end

      def files(root)
        Dir.glob('**/*', File::FNM_DOTMATCH, base: root)
           .select { EXTENSIONS.include?(File.extname(it).delete_prefix('.')) }
           .reject { it.split('/').intersect?(SKIPPED) }.sort.map { File.join(root, it) }
      end

      # Each line that starts a function, to where the indent comes back to its own, named after the class it's in.
      def indented_in(path)
        lines = File.readlines(path, chomp: true)
        lines.each_index.filter_map do |index|
          name = lines[index][DEFINITION, 1]
          next unless name

          CodeMethod.new(path:, owner: owner_of(lines, index), name:, line: index + 1,
                         lines: lines[index..block_end(lines, index)], changes: 0, drift: 0)
        end
      rescue SystemCallError, ArgumentError
        []
      end

      # The block's last line: the last one indented further than its first, or the line closing it, like "end".
      def block_end(lines, index)
        start = indent(lines[index])
        last = index
        lines.each_with_index.drop(index + 1).each do |line, number|
          next if line.strip.empty?
          return number if indent(line) == start && line.match?(CLOSER)
          return last if indent(line) <= start

          last = number
        end
        last
      end

      # The class or the like that the line's inside, by the nearest line above that's indented less and starts one.
      def owner_of(lines, index)
        depth = indent(lines[index])
        owner = lines[0...index].reverse_each.find { indent(it) < depth && it.match?(OWNER) }
        owner && owner[OWNER, 1].split('::').last
      end

      def indent(line) = line[/\A\s*/].length

      # How many commits changed each file, from git log, or none outside a repository.
      def file_changes(root)
        log, status = Open3.capture2('git', '-C', root, 'log', '--format=', '--name-only', '--relative', err: File::NULL)
        return {} unless status.success?

        log.split("\n").reject(&:empty?).tally.transform_keys { File.join(root, it) }
      rescue SystemCallError
        {}
      end
    end
  end
end
