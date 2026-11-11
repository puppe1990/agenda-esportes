# frozen_string_literal: true

require_relative "sport_slug"

module GeParser
  def self.parse(payload)
    data = payload["data"] || payload
    if data["multisportTabAgenda"]
      parse_tabs(data["multisportTabAgenda"])
    elsif data["championshipsAgenda"]
      parse_championships(data["championshipsAgenda"], sport_name: "Futebol")
    else
      []
    end
  end

  def self.parse_tabs(tabs)
    Array(tabs).flat_map do |tab|
      parse_championships(tab["championshipsAgenda"], sport_name: tab.dig("sport", "name"))
    end
  end
  private_class_method :parse_tabs

  def self.parse_championships(rows, sport_name:)
    name = sport_name.to_s
    slug = SportSlug.call(name)
    Array(rows).flat_map do |row|
      competition = row.dig("championship", "name").to_s
      buckets(row).filter_map { |item| event_from(item, slug: slug, sport_name: name, competition: competition) }
    end
  end
  private_class_method :parse_championships

  def self.buckets(row)
    Array(row["now"]) + Array(row["past"]) + Array(row["future"])
  end
  private_class_method :buckets

  def self.event_from(item, slug:, sport_name:, competition:)
    # Live GE wraps fields under match; flattened fixtures skip that key.
    match = item["match"] || item
    first = contestant_name(match["firstContestant"])
    second = contestant_name(match["secondContestant"])
    return if first.nil? || second.nil?

    hour = match["startHour"].to_s
    timed = !hour.empty?
    date = match["startDate"].to_s
    starts_at = timed ? "#{date}T#{hour}-03:00" : "#{date}T00:00:00-03:00"

    {
      ge_id: match["id"].to_s,
      sport: slug,
      sport_name: sport_name,
      title: "#{first} x #{second}",
      starts_at: starts_at,
      timed: timed,
      competition: competition,
      watch_on: watch_line(match["liveWatchSources"]),
      note: note_line(competition, match)
    }
  end
  private_class_method :event_from

  def self.contestant_name(node)
    return if node.nil?

    name = node["popularName"].to_s.strip
    name.empty? ? nil : name
  end
  private_class_method :contestant_name

  def self.watch_line(sources)
    names = Array(sources).map { |source| source["name"].to_s.strip }.reject(&:empty?)
    names.empty? ? nil : names.join(" · ")
  end
  private_class_method :watch_line

  def self.note_line(competition, match)
    bits = [competition]
    phase = match.dig("phase", "name").to_s.strip
    bits << phase unless phase.empty?
    round = match["round"]
    bits << "rodada #{round}" if phase.empty? && !round.nil?
    bits.join(" · ")
  end
  private_class_method :note_line
end
