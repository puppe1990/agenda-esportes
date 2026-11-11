# frozen_string_literal: true

class EmptyGeClient
  def championships_agenda(_date)
    { "data" => { "championshipsAgenda" => [] } }
  end

  def multisport_agenda(_date)
    { "data" => { "multisportTabAgenda" => [] } }
  end
end

class DownGeClient
  def championships_agenda(_date)
    raise GeClient::Error, "geql down"
  end

  def multisport_agenda(_date)
    raise GeClient::Error, "geql down"
  end
end
