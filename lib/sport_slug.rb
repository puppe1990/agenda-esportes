# frozen_string_literal: true

module SportSlug
  def self.call(name)
    text = name.to_s.unicode_normalize(:nfkd).gsub(/\p{M}/, "")
    text.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
  end
end
