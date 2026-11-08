# frozen_string_literal: true

module SportsCatalog
  Item = Struct.new(:slug, :name, keyword_init: true)

  ALL = [
    Item.new(slug: "futebol", name: "Futebol"),
    Item.new(slug: "nfl", name: "NFL"),
    Item.new(slug: "nba", name: "NBA"),
    Item.new(slug: "automobilismo", name: "Automobilismo")
  ].freeze

  class UnknownSport < ArgumentError; end

  def self.slugs
    ALL.map(&:slug)
  end

  def self.find!(slug)
    found = ALL.find { |sport| sport.slug == slug.to_s }
    return found if found

    raise UnknownSport,
          "esporte desconhecido: #{slug.inspect} (esperado: #{slugs.join(', ')})"
  end
end
