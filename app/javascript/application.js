// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import "controllers"

// Direct upload: trình duyệt xin presigned URL từ Rails rồi PUT thẳng lên S3.
// Ảnh KHÔNG đi qua Puma — một check-in 10 ảnh trên 4G không còn giữ worker.
ActiveStorage.start()
