require "csv"

class UsersController < ApplicationController
  include UserPermissionsControllerMethods

  layout "admin_layout", only: %w[index event_logs require_2sv]

  before_action :authenticate_user!, except: :show
  before_action :load_and_authorize_user, except: %i[index show]
  before_action :allow_no_application_access, only: [:update]
  before_action :redirect_legacy_filters, only: [:index]
  helper_method :applications_and_permissions, :filter_params
  respond_to :html

  before_action :doorkeeper_authorize!, only: :show
  before_action :validate_token_matches_client_id, only: :show
  skip_after_action :verify_authorized, only: :show

  def show
    current_resource_owner.permissions_synced!(application_making_request)
    respond_to do |format|
      format.json do
        presenter = UserOAuthPresenter.new(current_resource_owner, application_making_request)
        render json: presenter.as_hash.to_json
      end
    end
  end

  def index
    authorize User

    @filter = UsersFilter.new(policy_scope(User), current_user, filter_params)

    respond_to do |format|
      format.html do
        @users = @filter.paginated_users
      end
      format.csv do
        @users = @filter.users
        headers["Content-Disposition"] = 'attachment; filename="signon_users.csv"'
        render plain: export, content_type: "text/csv"
      end
    end
  end

  def edit
    @application_permissions = all_applications_and_permissions_for(@user)
  end

  def update
    raise Pundit::NotAuthorizedError if params[:user][:organisation_id].present? && !policy(@user).assign_organisations?

    updater = UserUpdate.new(@user, user_params, current_user, user_ip_address)
    if updater.call
      redirect_to users_path, notice: "Updated user #{@user.email} successfully"
    else
      @application_permissions = all_applications_and_permissions_for(@user)
      render :edit
    end
  end

  def unlock
    EventLog.record_event(@user, EventLog::MANUAL_ACCOUNT_UNLOCK, initiator: current_user, ip_address: user_ip_address)
    @user.unlock_access!
    flash[:notice] = "Unlocked #{@user.email}"
    redirect_back_or_to(root_path)
  end

  def resend_email_change
    @user.resend_confirmation_instructions
    if @user.errors.empty?
      redirect_to root_path, notice: "Successfully resent email change email to #{@user.unconfirmed_email}"
    else
      redirect_to edit_user_path(@user), alert: "Failed to send email change email"
    end
  end

  def cancel_email_change
    @user.cancel_email_change!

    redirect_back_or_to(root_path)
  end

  def event_logs
    authorize @user
    @logs = @user.event_logs.page(params[:page]).per(100) if @user
  end

  def reset_two_step_verification
    @user.reset_2sv!(current_user)
    UserMailer.two_step_reset(@user).deliver_later

    redirect_to :root, notice: "Reset 2-step verification for #{@user.email}"
  end

  def require_2sv; end

private

  def load_and_authorize_user
    @user = current_user.normal? ? current_user : User.find(params[:id])
    redirect_to(account_path) and return if current_user == @user && action_name == "edit"

    authorize @user
  end

  def should_include_permissions?
    params[:format] == "csv"
  end

  def validate_token_matches_client_id
    # FIXME: Once gds-sso is updated everywhere, this should always validate
    # the client_id param.  It should 401 if no client_id is given.
    if params[:client_id].present? && (params[:client_id] != doorkeeper_token.application.uid)
      head :unauthorized
    end
  end

  def export
    applications = Doorkeeper::Application.all
    CSV.generate do |csv|
      presenter = UserExportPresenter.new(applications)
      csv << presenter.header_row
      @users.find_each do |user|
        csv << presenter.row(user)
      end
    end
  end

  # When no permissions are selected for a user, we set the value to [] so
  # a user can have no permissions
  def allow_no_application_access
    params[:user] ||= {}
    params[:user][:supported_permission_ids] ||= []
  end

  def user_params
    if permitted_user_params[:skip_update_user_permissions]
      permitted_user_params[:supported_permission_ids] = @user.supported_permission_ids
    end

    UserParameterSanitiser.new(
      user_params: permitted_user_params,
      current_user_role: current_user.role.to_sym,
    ).sanitise
  end

  def permitted_user_params
    @permitted_user_params ||= params.require(:user).permit(:user, :name, :email, :organisation_id, :require_2sv, :role, :skip_update_user_permissions, supported_permission_ids: []).to_h
  end

  def filter_params
    params.permit(
      :filter, :page, :format, :"option-select-filter",
      *LegacyUsersFilter::PARAM_KEYS,
      **UsersFilter::PERMITTED_CHECKBOX_FILTER_PARAMS
    ).except(:"option-select-filter")
  end

  def redirect_legacy_filters
    filter = LegacyUsersFilter.new(filter_params)
    if filter.redirect?
      redirect_to users_path(filter.options)
    end
  end
end
