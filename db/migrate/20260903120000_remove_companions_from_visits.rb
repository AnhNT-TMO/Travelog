class RemoveCompanionsFromVisits < ActiveRecord::Migration[8.1]
  def change
    remove_column :visits, :companions, :string
  end
end
