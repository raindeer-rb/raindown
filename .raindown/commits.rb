# frozen_string_literal: true

require 'open3'

# The latest commits, charting the lines each one deleted against the lines it added:
#   <{ Commits: limit=5 }>
# It's a chart: whose data comes from git log rather than a file, so it takes the same props, like width:.
class Commits < Raindown::Chart
  def initialize(limit: 5, width: 30, **props)
    super(minus: 'deleted', width:, **props)
    @limit = limit
  end

  def points(metadata: Raindown::NoMetadata)
    root = metadata.respond_to?(:root) ? metadata.root : Dir.pwd
    Points.new(minus: @minus, root:).from(commits(root))
  end

  private

  # Each commit's short hash with the lines it added and deleted, newest first. Merges change nothing of their own.
  def commits(root)
    log, status = Open3.capture2('git', '-C', root, 'log', '--no-merges', "-n#{@limit}", '--numstat', '--format=%h')
    raise Error, 'git log failed' unless status.success?

    log.split("\n").each_with_object([]) do |line, commits|
      added, deleted, = line.split("\t")

      if deleted.nil?
        commits << { 'commit' => line, 'added' => 0, 'deleted' => 0 } unless line.empty?
      else
        # Binary files show - for both counts, which to_i makes 0.
        commits.last['added'] += added.to_i
        commits.last['deleted'] += deleted.to_i
      end
    end
  end
end
