class Bunny
  attr_reader :client

  class << self
    def sync
      new.sync
    end
  end

  def initialize(access_key: nil, library_id: nil)
    access_key ||= Rails.application.credentials.bunny_access_key
    library_id ||= Rails.application.credentials.bunny_library_id

    @client = BunnyClient.new(access_key: access_key, library_id: library_id)
  end

  def sync(page: 1, per_page: 1000)
    loop do
      response = client.videos(page: page, per_page: per_page)
      ApplicationRecord.transaction do
        response[:item].each { sync_video(_1) }
      end
      next_page = response[:currentPage] * response[:itemPerPage] < response[:totalItems]
      break unless next_page
      page += 1
    end
  end

  def sync_vide
    video = Video.where(guid: item[:guid]).first_or_initialize
    video.update(
      library_id: item[:videoLibraryId],
      title: item[:title],
      captions: item[:captions].any? { _1[:label] == 'English' }
    )
  end

  def upload_captions(guid:, captions_path:)
    content = Base64.encode64(File.read(captions_path))
    post("/videos/#{guid}/captions/en", body: {srclang: "en", label: "English", captionsFile: content})
  end
end
