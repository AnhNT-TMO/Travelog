require "io/console"

email = ENV.fetch("USER_EMAIL", "anhnt.tmo@gmail.com")
password = ENV["USER_PASSWORD"].presence

unless password
  abort "Set USER_PASSWORD or run this script interactively." unless $stdin.tty?

  print "Password: "
  password = $stdin.noecho(&:gets)&.chomp
  puts

  print "Confirm password: "
  confirmation = $stdin.noecho(&:gets)&.chomp
  puts

  abort "Passwords do not match." unless password == confirmation
end

abort "Password cannot be blank." if password.blank?

user = User.find_or_initialize_by(email: email)
created = user.new_record?

user.update!(password: password, password_confirmation: password)

puts "#{created ? "Created" : "Updated"} user: #{user.email}"
