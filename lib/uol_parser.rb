# frozen_string_literal: true

require "json"

# SoccerScore lives on commons.uol.com.br (no public DNS). The same
# payload is dumped into #VUELAND_CORE_STATE / #VUELAND_STATE on
# https://www.uol.com.br/esporte/futebol/central-de-jogos
module UolParser
  ID_PREFIX = "uol:"
  SCRIPT_IDS = %w[VUELAND_CORE_STATE VUELAND_STATE].freeze

  def self.parse(html)
    core, state = script_payloads(html)
    block = football_block(core)
    return [] if block.nil?

    teams = stringify_keys(block["teams"])
    champs = championships_from(state)
    stringify_keys(block["matches"]).filter_map do |id, match|
      event_from(id, match, teams: teams, champs: champs)
    end
  end

  def self.script_payloads(html)
    SCRIPT_IDS.map { |script_id| script_json(html, script_id) }
  end
  private_class_method :script_payloads

  def self.script_json(html, script_id)
    blob = html.to_s[/<script[^>]*id="#{script_id}"[^>]*>(.*?)<\/script>/m, 1]
    return {} if blob.nil? || blob.strip.empty?

    JSON.parse(blob)
  rescue JSON::ParserError => e
    raise Error, "UOL #{script_id} JSON inválido: #{e.message}"
  end
  private_class_method :script_json

  def self.football_block(core)
    components = core.dig("general", "components")
    return unless components.is_a?(Hash)

    key = components.keys.find { |name| name.to_s.start_with?("FootballDailyMatches") }
    components[key] if key
  end
  private_class_method :football_block

  def self.championships_from(state)
    stringify_keys(state).each_with_object({}) do |(key, row), hash|
      next unless key.start_with?("football-match-")
      next unless row.is_a?(Hash)

      id = key.delete_prefix("football-match-")
      hash[id] = row["championship"] || {}
    end
  end
  private_class_method :championships_from

  def self.event_from(id, match, teams:, champs:)
    return unless match.is_a?(Hash)
    return if broadcasts(match).empty?

    home = team_name(teams, match.dig("teams", "home"))
    away = team_name(teams, match.dig("teams", "away"))
    return if home.nil? || away.nil?

    date = match["date"].to_s
    return if date.empty?

    hour = clock(match["hour"])
    timed = !hour.nil?
    championship = championship_name(id, match, champs)

    {
      ge_id: "#{ID_PREFIX}#{id}",
      sport: "futebol",
      sport_name: "Futebol",
      title: "#{home} x #{away}",
      starts_at: timed ? "#{date}T#{hour}-03:00" : "#{date}T00:00:00-03:00",
      timed: timed,
      competition: championship,
      watch_on: broadcasts(match).join(" · "),
      note: note_line(championship, match)
    }
  end
  private_class_method :event_from

  def self.broadcasts(match)
    Array(match.dig("content", "broadcast")).map { |row| broadcast_name(row) }.reject(&:empty?)
  end
  private_class_method :broadcasts

  def self.broadcast_name(row)
    row.is_a?(Hash) ? row["name"].to_s.strip : row.to_s.strip
  end
  private_class_method :broadcast_name

  def self.team_name(teams, id)
    return if id.nil?

    name = teams[id.to_s].to_h["name"].to_s.strip
    name.empty? ? nil : name
  end
  private_class_method :team_name

  def self.clock(hour)
    text = hour.to_s.strip
    return if text.empty?

    captured = text.match(/\A(\d{1,2})h(\d{2})?\z/)
    return unless captured

    hours = captured[1].to_i
    minutes = (captured[2] || "00").to_i
    format("%02d:%02d:00", hours, minutes)
  end
  private_class_method :clock

  def self.championship_name(id, match, champs)
    name = champs[id.to_s].to_h["name"].to_s.strip
    name = match.dig("championship", "name").to_s.strip if name.empty?
    name.empty? ? "Futebol" : name
  end
  private_class_method :championship_name

  def self.note_line(championship, match)
    bits = [championship]
    phase = match.dig("championship", "phase").to_s.strip
    bits << phase unless phase.empty?
    round = match["round"]
    bits << "rodada #{round}" if phase.empty? && !round.nil?
    bits.join(" · ")
  end
  private_class_method :note_line

  def self.stringify_keys(hash)
    return {} unless hash.is_a?(Hash)

    hash.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
  end
  private_class_method :stringify_keys

  class Error < StandardError; end
end
