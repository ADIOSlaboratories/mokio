class AddNameToMokioUsers < ActiveRecord::Migration
  def change
    add_column :mokio_users, :first_name, :string, after: :email
    add_column :mokio_users, :last_name, :string, after: :first_name
  end
end
