# frozen_string_literal: true

# The code's debt, from how it feels now, sorted in raindown tui's Code feelings: each feeling's CodeHealth score, as how
# far it is from numb, from 1 for frolic to -1 for malice, added up, so it's in debt below zero. Its label says how many
# fixes there have been, feelings that scored higher when their method was felt again, once its code had changed:
#   <{ CodeDebt: }>
# Only the feelings count towards the debt, not the memories, which are about code that's since changed or gone.
class CodeDebt < Raindown::Stat
  # Card lines ask for the value before the label, which counts the fixes in the same project.
  def value(metadata: Raindown::NoMetadata)
    @root = root(metadata)
    CodeHealth.rows(@root, 'feelings').sum { (CodeHealth.score(it).to_f - 0.5) * 2 }
  end

  def label
    count = fixes
    return '1 fix' if count == 1

    "#{count} fixes"
  end

  # To one decimal place, with its sign, like +1.5 or -2.7, apart from 0.
  def number(value)
    return '0' if value.round(1).zero?

    format('%+.1f', value)
  end

  # The memories whose method's next feeling scored higher. A method's memories come oldest first, then its feeling now.
  def fixes
    memories = CodeHealth.rows(@root, 'memories')
    history = memories + CodeHealth.rows(@root, 'feelings')
    memories.each_index.count do |index|
      later = history[(index + 1)..].find { row_method(it) == row_method(history[index]) }
      later && CodeHealth.score(later).to_f > CodeHealth.score(history[index]).to_f
    end
  end

  private

  # The file and name of the row's method, wherever its line was.
  def row_method(row) = [row['location'].sub(/:\d+\z/, ''), row['method']]
end
