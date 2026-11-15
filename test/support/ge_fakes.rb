# frozen_string_literal: true

class EmptyGeClient
  def agenda_range(dates)
    dates.to_h do |date|
      [date, { "championshipsAgenda" => { "data" => { "championshipsAgenda" => [] } },
               "multisportTabAgenda" => { "data" => { "multisportTabAgenda" => [] } } }]
    end
  end
end

class DownGeClient
  def agenda_range(_dates)
    raise GeClient::Error, "geql down"
  end
end
