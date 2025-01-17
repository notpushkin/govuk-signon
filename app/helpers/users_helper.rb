module UsersHelper
  def two_step_status(user)
    user.two_step_status.humanize.capitalize
  end

  def organisation_options(form_builder)
    accessible_organisations = policy_scope(Organisation)
    options_from_collection_for_select(
      accessible_organisations,
      :id,
      :name_with_abbreviation,
      selected: form_builder.object.organisation_id,
    )
  end

  def organisation_select_options
    { include_blank: current_user.publishing_manager? ? false : "None" }
  end

  def user_email_tokens(user = current_user)
    [user.email] + DeviseZxcvbn::EmailTokeniser.split(user.email)
  end

  def minimum_password_length
    User.password_length.min
  end

  def edit_user_path_by_user_type(user)
    user.api_user? ? edit_api_user_path(user) : edit_user_path(user)
  end

  def sync_needed?(permissions)
    max_updated_at = permissions.map(&:updated_at).compact.max
    max_last_synced_at = permissions.map(&:last_synced_at).compact.max
    max_updated_at.present? && max_last_synced_at.present? ? max_updated_at > max_last_synced_at : false
  end

  def formatted_number_of_users(users)
    pluralize(number_with_delimiter(users.total_count), "user")
  end

  def filtered_users_heading(users)
    count = formatted_number_of_users(users)
    if current_user.manageable_organisations.one?
      "#{count} in #{current_user.manageable_organisations.first.name}"
    else
      count
    end
  end

  def assignable_user_roles
    current_user.manageable_roles
  end

  def user_name(user)
    anchor_tag = link_to(user.name, edit_user_path(user), class: "govuk-link")
    user.suspended? ? content_tag(:del, anchor_tag) : anchor_tag
  end
end
