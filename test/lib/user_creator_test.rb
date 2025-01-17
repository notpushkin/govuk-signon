require "test_helper"

class UserCreatorTest < ActiveSupport::TestCase
  test "it creates a new user with the supplied name and email" do
    FactoryBot.create(:application, name: "app-o-tron", with_supported_permissions: [SupportedPermission::SIGNIN_NAME])
    user_creator = UserCreator.new("Alicia", "alicia@example.com", "app-o-tron")

    user_creator.create_user!

    assert user_creator.user.persisted?
    assert_equal "Alicia", user_creator.user.name
    assert_equal "alicia@example.com", user_creator.user.email
  end

  test "invites the new user, so they must validate their email before they can signin" do
    FactoryBot.create(:application, name: "app-o-tron", with_supported_permissions: [SupportedPermission::SIGNIN_NAME])
    user_creator = UserCreator.new("Alicia", "alicia@example.com", "app-o-tron")

    user_creator.create_user!

    assert user_creator.user.invited_but_not_yet_accepted?
  end

  test 'it grants "signin" permission to each application supplied' do
    app_o_tron = FactoryBot.create(:application, name: "app-o-tron", with_supported_permissions: [SupportedPermission::SIGNIN_NAME])
    app_erator = FactoryBot.create(:application, name: "app-erator", with_supported_permissions: [SupportedPermission::SIGNIN_NAME])
    user_creator = UserCreator.new("Alicia", "alicia@example.com", "app-o-tron,app-erator")

    user_creator.create_user!

    assert user_creator.user.has_access_to? app_o_tron
    assert user_creator.user.has_access_to? app_erator
  end

  test "it grants all default permissions, even if not signin" do
    app_o_tron = FactoryBot.create(:application, name: "app-o-tron", with_supported_permissions: [SupportedPermission::SIGNIN_NAME])
    app_erator = FactoryBot.create(:application, name: "app-erator", with_supported_permissions: [SupportedPermission::SIGNIN_NAME, "fall"])
    create(:supported_permission, application: app_o_tron, name: "bounce", default: true)
    app_erator.signin_permission.update!(default: true)
    user_creator = UserCreator.new("Alicia", "alicia@example.com", "")

    user_creator.create_user!

    created_user = user_creator.user
    assert_equal %w[bounce], created_user.permissions_for(app_o_tron)
    assert_equal [SupportedPermission::SIGNIN_NAME], created_user.permissions_for(app_erator)
  end
end
