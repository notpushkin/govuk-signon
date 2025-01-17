class UserPolicy < BasePolicy
  def index?
    %w[superadmin admin super_organisation_admin organisation_admin].include? current_user.role
  end

  # invitations#new
  def new?
    %w[superadmin admin].include? current_user.role
  end
  alias_method :assign_organisations?, :new?

  # invitations#create
  alias_method :create?, :new?

  def edit?
    return false if current_user == record

    case current_user.role
    when Roles::Superadmin.role_name
      true
    when Roles::Admin.role_name
      can_manage?
    when Roles::SuperOrganisationAdmin.role_name
      can_manage? && (record_in_own_organisation? || record_in_child_organisation?)
    when Roles::OrganisationAdmin.role_name
      can_manage? && record_in_own_organisation?
    else # 'normal'
      false
    end
  end
  alias_method :update?, :edit?
  alias_method :unlock?, :edit?
  alias_method :suspension?, :edit?
  alias_method :resend?, :edit?
  alias_method :event_logs?, :edit?
  alias_method :mandate_2sv?, :edit?
  alias_method :require_2sv?, :edit?
  alias_method :reset_2sv?, :edit?
  alias_method :reset_two_step_verification?, :edit?
  alias_method :resend_email_change?, :edit?
  alias_method :cancel_email_change?, :edit?

  def assign_role?
    current_user.superadmin?
  end

  def exempt_from_two_step_verification?
    current_user.belongs_to_gds? &&
      current_user.govuk_admin? &&
      record.normal? &&
      !record.api_user
  end

private

  def can_manage?
    current_user.can_manage?(record)
  end

  class Scope < ::BasePolicy::Scope
    def resolve
      if current_user.superadmin?
        scope.web_users
      elsif current_user.admin?
        scope.web_users.where(role: current_user.manageable_roles)
      elsif current_user.super_organisation_admin?
        scope.web_users.where(role: current_user.manageable_roles).where(organisation: current_user.organisation.subtree)
      elsif current_user.organisation_admin?
        scope.web_users.where(role: current_user.manageable_roles).where(organisation: current_user.organisation)
      else
        scope.none
      end
    end
  end
end
