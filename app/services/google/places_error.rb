module Google
  class PlacesError < StandardError
    attr_reader :status, :request_id

    def initialize(message, status: nil, request_id: nil)
      @status = status
      @request_id = request_id
      super(message)
    end
  end
end
