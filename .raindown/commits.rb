# frozen_string_literal: true

require 'open3'

# The latest commits, under a Total of their lines, charting the lines each one deleted against the lines it added:
#   <{ Commits: limit=5 }>
# It's a chart: whose data comes from git log rather than a file, so it takes the same props, like width:.
class Commits < Raindown::Chart
  def initialize(limit: 5, width: 30, **props)
    super(minus: 'deleted', width:, **props)
    @limit = limit
  end

  def points(metadata: Raindown::NoMetadata)
    root = metadata.respond_to?(:root) ? metadata.root : Dir.pwd
    commits = commits(root)
    commits.unshift(total(commits)) unless commits.empty?
    Points.new(minus: @minus, root:).from(commits)
  end

  # A line across the chart between the Total and the commits.
  def draw(points)
    lines = super
    lines.insert(1, '─' * lines.map { it.rstrip.length }.max)
  end

  private

  # All the lines the commits below it added and deleted.
  def total(commits)
    { 'commit' => 'Total', 'added' => commits.sum { it['added'] }, 'deleted' => commits.sum { it['deleted'] } }
  end

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
