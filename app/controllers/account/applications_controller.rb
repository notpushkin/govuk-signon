class Account::ApplicationsController < ApplicationController
  layout "admin_layout"

  before_action :authenticate_user!

  def show
    authorize [:account, Doorkeeper::Application]

    redirect_to account_applications_path
  end

  def index
    authorize [:account, Doorkeeper::Application]

    @applications_with_signin = Doorkeeper::Application.can_signin(current_user)
    @applications_without_signin = Doorkeeper::Application.not_retired.without_signin_permission_for(current_user)
  end
end
