module Photos
  class ThumbnailUrl
    SIZES = Rails.application.config.settings.photo_sizes.map(&:to_i).freeze

    THUMB   = SIZES.first
    PREVIEW = SIZES.last
    DIRECTORY_BY_SIZE = {
      THUMB => "thumb",
      PREVIEW => "preview"
    }.freeze

    class << self
      def call(s3_key, size = THUMB, place_id:)
        raise ArgumentError, "size không hỗ trợ: #{size.inspect}" unless SIZES.include?(size)
        return nil if s3_key.blank?

        "#{cdn_host}/#{place_id_for(place_id)}/#{DIRECTORY_BY_SIZE.fetch(size)}/#{image_name(s3_key)}.webp"
      end

      def srcset(s3_key, place_id:)
        return nil if s3_key.blank?

        SIZES.map { |size| "#{call(s3_key, size, place_id: place_id)} #{size}w" }.join(", ")
      end

      private

      def cdn_host = Rails.application.config.settings.cdn_host.to_s.chomp("/")

      def image_name(s3_key)
        filename = File.basename(s3_key.to_s)
        filename.delete_suffix(File.extname(filename))
      end

      def place_id_for(place_id)
        Integer(place_id.to_s, 10).tap do |id|
          raise ArgumentError, "place_id không hợp lệ: #{place_id.inspect}" unless id.positive?
        end
      rescue ArgumentError, TypeError
        raise ArgumentError, "place_id không hợp lệ: #{place_id.inspect}"
      end
    end
  end
end
