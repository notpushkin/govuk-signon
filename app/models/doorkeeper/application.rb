require "doorkeeper/orm/active_record/application"

# rubocop:disable Rails/ApplicationRecord
class ::Doorkeeper::Application < ActiveRecord::Base
  # rubocop:enable Rails/ApplicationRecord
  has_many :supported_permissions, dependent: :destroy

  default_scope { order("oauth_applications.name") }
  scope :support_push_updates, -> { where(supports_push_updates: true) }
  scope :not_retired, -> { where(retired: false) }
  scope :can_signin,
        lambda { |user|
          with_signin_permission_for(user)
            .not_retired
        }
  scope :with_signin_delegatable,
        lambda {
          joins(:supported_permissions)
            .merge(SupportedPermission.signin)
            .merge(SupportedPermission.delegatable)
        }
  scope :with_signin_permission_for,
        lambda { |user|
          joins(supported_permissions: :user_application_permissions)
            .where(user_application_permissions: { user: })
            .merge(SupportedPermission.signin)
        }
  scope :without_signin_permission_for,
        lambda { |user|
          excluded_app_ids = with_signin_permission_for(user).map(&:id)
          where.not(id: excluded_app_ids)
        }

  after_create :create_signin_supported_permission
  after_save :create_user_update_supported_permission

  def self.policy_class
    ApplicationPolicy
  end

  def supported_permission_strings(user = nil)
    if user && %w[organisation_admin super_organisation_admin].include?(user.role)
      supported_permissions.delegatable.pluck(:name) & user.permissions_for(self)
    else
      supported_permissions.pluck(:name)
    end
  end

  def signin_permission
    supported_permissions.signin.first
  end

  def sorted_supported_permissions_grantable_from_ui
    ([signin_permission] + (supported_permissions.grantable_from_ui.order(:name) - [signin_permission])).compact
  end

  def url_without_path
    parsed_url = URI.parse(redirect_uri)
    "#{parsed_url.scheme}://#{parsed_url.host}:#{parsed_url.port}"
  end

  def gds_only?
    [
      "Collections Publisher",
      "Publisher",
      "Service Manual Publisher",
    ].include?(name)
  end

  def redirect_uri
    substituted_uri(self[:redirect_uri])
  end

  def home_uri
    substituted_uri(self[:home_uri])
  end

private

  def substituted_uri(uri)
    uri_pattern = Rails.configuration.oauth_apps_uri_sub_pattern
    uri_sub = Rails.configuration.oauth_apps_uri_sub_replacement

    if uri_pattern.present? && uri_sub.present?
      uri.sub(uri_pattern, uri_sub)
    else
      uri
    end
  end

  def create_signin_supported_permission
    supported_permissions.delegatable.signin.create!
  end

  def create_user_update_supported_permission
    supported_permissions.where(name: "user_update_permission", grantable_from_ui: false).first_or_create! if supports_push_updates?
  end
end
