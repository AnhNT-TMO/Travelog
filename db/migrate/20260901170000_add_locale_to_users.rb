class AddLocaleToUsers < ActiveRecord::Migration[8.1]
  def change
    # null = theo ngôn ngữ mặc định của app. Chỉ ghi khi người dùng chủ động đổi.
    add_column :users, :locale, :string
  end
end
