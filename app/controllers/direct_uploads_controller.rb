class DirectUploadsController < ApplicationController
  include ActiveStorage::SetCurrent

  def create
    user_place = scoped_places.find(params[:place_id])
    attributes = blob_args
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      **attributes,
      key: original_key(user_place, attributes.fetch(:filename))
    )

    render json: direct_upload_json(blob)
  end

  private

  def blob_args
    params.expect(blob: [ :filename, :byte_size, :checksum, :content_type, { metadata: {} } ])
          .to_h
          .symbolize_keys
  end

  def direct_upload_json(blob)
    blob.as_json(root: false, methods: :signed_id).merge(
      direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      }
    )
  end

  def original_key(user_place, filename)
    extension = File.extname(filename.to_s).delete_prefix(".").downcase
    extension = "jpg" if extension == "jpeg"
    extension = "bin" if extension.blank?

    basename = File.basename(filename.to_s, File.extname(filename.to_s))
    image_name = Vietnamese.slugify(basename).presence || "image"

    "#{user_place.id}/#{image_name}-#{SecureRandom.hex(6)}.#{extension}"
  end
end
