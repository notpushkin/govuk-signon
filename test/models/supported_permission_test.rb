require "test_helper"

class SupportedPermissionTest < ActiveSupport::TestCase
  test "name of signin permission cannot be changed" do
    application = create(:application)

    assert_raises ActiveRecord::RecordInvalid do
      application.signin_permission.update!(name: "sign-in")
    end
  end

  test "name of permissions other than signin be changed" do
    permission = create(:supported_permission, name: "writer")

    assert_nothing_raised do
      permission.update!(name: "write")
    end
  end

  test "name of permission must be unique" do
    application = create(:application)
    create(:supported_permission, name: "writer", application:)
    copy_cat_permission = build(:supported_permission, name: "writer", application:)

    assert_not copy_cat_permission.valid?
    assert_includes copy_cat_permission.errors[:name], "has already been taken"
  end

  test "associated user application permissions are destroyed when supported permissions are destroyed" do
    user = create(:user)
    application = create(:application, with_supported_permissions: %w[managing_editor])
    managing_editor_permission = application.supported_permissions.where(name: "managing_editor").first

    user.grant_application_permission(application, "managing_editor")
    managing_editor_permission.destroy!

    assert_empty user.reload.application_permissions
  end

  test "we can find all the default permissions" do
    application_one = create(:application)
    permission_one = create(:supported_permission, application: application_one, name: "writer")
    permission_two = create(:supported_permission, application: application_one, name: "reader", default: true)
    permission_three = create(:supported_permission, application: application_one, name: "critic")

    application_two = create(:application)
    application_two.signin_permission.update!(default: true)
    permission_four = create(:supported_permission, application: application_two, name: "ignorer", default: true)

    default_permissions = SupportedPermission.default
    assert default_permissions.include? permission_two
    assert default_permissions.include? permission_four
    assert default_permissions.include? application_two.signin_permission

    assert_not default_permissions.include? permission_one
    assert_not default_permissions.include? permission_three
    assert_not default_permissions.include? application_one.signin_permission
  end

  test ".signin returns all signin permissions" do
    app1 = create(:application, with_supported_permissions: %w[app1-permission])
    app2 = create(:application, with_supported_permissions: %w[app2-permission])

    assert_same_elements [app1.signin_permission, app2.signin_permission], SupportedPermission.signin
  end
end
