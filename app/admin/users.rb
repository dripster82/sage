# frozen_string_literal: true

ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :credits

  index do
    selectable_column
    id_column
    column :email
    column :credits
    column :created_at
    column :last_seen
    actions
  end

  filter :email
  filter :credits
  filter :created_at
  filter :last_seen

  form do |f|
    f.inputs do
      f.input :email
      f.input :password
      f.input :password_confirmation
      f.input :credits, input_html: { min: 0 }
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :email
      row :credits
      row :created_at
      row :updated_at
      row :last_seen
    end
  end

  controller do
    def create
      @user = User.new(permitted_params[:user])
      if @user.save
        redirect_to admin_user_path(@user), notice: 'User was successfully created.'
      else
        render :new
      end
    end

    def update
      @user = User.find(params[:id])
      if @user.update(permitted_params[:user])
        redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
      else
        render :edit
      end
    end
  end
end

