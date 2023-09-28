require "test_helper"

class InvitationsControllerTest < ActionController::TestCase
  setup do
    request.env["devise.mapping"] = Devise.mappings[:user]
  end

  context "GET new" do
    context "when inviter is not signed in" do
      should "require inviter to be signed in" do
        get :new

        assert_redirected_to new_user_session_path
      end
    end

    context "when inviter is signed in" do
      context "and inviter is not an admin" do
        setup do
          sign_in create(:user)
        end

        should "disallow access" do
          get :new

          assert_redirected_to root_path
        end
      end

      context "and inviter is an organisation admin" do
        setup do
          sign_in create(:organisation_admin_user)
        end

        should "disallow access" do
          get :new

          assert_redirected_to root_path
        end
      end

      context "and inviter is a super organisation admin" do
        setup do
          sign_in create(:super_organisation_admin_user)
        end

        should "disallow access" do
          get :new

          assert_redirected_to root_path
        end
      end
    end
  end

  context "POST create" do
    context "when inviter is not signed in" do
      should "require inviter to be signed in" do
        post :create

        assert_redirected_to new_user_session_path
      end
    end

    context "when inviter is signed in" do
      setup do
        @inviter = create(:superadmin_user)
        sign_in @inviter
      end

      context "and inviter is not an admin" do
        setup do
          sign_in create(:user)
        end

        should "disallow access" do
          post :create, params: { user: { name: "invitee", email: "invitee@gov.uk" } }

          assert_redirected_to root_path
        end
      end

      should "not allow creation of api users" do
        post :create, params: { user: { name: "api-invitee", email: "api-invitee@gov.uk", api_user: true } }

        assert_empty User.where(api_user: true)
      end

      should "redirect to users page and display flash alert when inviting an existing user" do
        existing_user = create(:user)

        post :create, params: { user: { name: existing_user.name, email: existing_user.email } }

        assert_redirected_to users_path
        assert_equal "User already invited. If you want to, you can click 'Resend signup email'.", flash[:alert]
      end

      context "and inviter is an organisation admin" do
        setup do
          sign_in create(:organisation_admin_user)
        end

        should "disallow access" do
          post :create, params: { user: { name: "org-admin-invitee", email: "org-admin-invitee@gov.uk" } }

          assert_redirected_to root_path
        end
      end

      context "and inviter is a super organisation admin" do
        setup do
          sign_in create(:super_organisation_admin_user)
        end

        should "disallow access" do
          post :create, params: { user: { name: "super-org-admin-invitee", email: "super-org-admin-invitee@gov.uk" } }

          assert_redirected_to root_path
        end
      end

      should "save invitee and render 2SV form when invitee will be assigned to organisation that does not require 2SV" do
        organisation = create(:organisation, require_2sv: false)

        post :create, params: { user: { name: "invitee", email: "invitee@gov.uk", organisation_id: organisation.id } }

        assert_redirected_to require_2sv_user_path(User.last)
        assert_equal "invitee", User.last.name
      end

      should "save invitee and not render 2SV form when invitee will be assigned to organisation that requires 2SV" do
        organisation = create(:organisation, require_2sv: true)

        post :create, params: { user: { name: "invitee", email: "invitee@gov.uk", organisation_id: organisation.id } }

        assert_redirected_to users_path
        assert_equal "invitee", User.last.name
      end

      should "not render 2SV form and saves invitee when invitee will be a superadmin" do
        organisation = create(:organisation, require_2sv: false)

        post :create, params: { user: { name: "superadmin-invitee", email: "superadmin-invitee@gov.uk", organisation_id: organisation.id, role: Roles::Superadmin.role_name } }

        assert_redirected_to users_path
        assert_equal "superadmin-invitee", User.last.name
        assert User.last.require_2sv
      end

      should "not render 2SV form and saves invitee when invitee will be an admin" do
        organisation = create(:organisation, require_2sv: false)

        post :create, params: { user: { name: "admin-invitee", email: "admin-invitee@gov.uk", organisation_id: organisation.id, role: Roles::Admin.role_name } }

        assert_redirected_to users_path
        assert_equal "admin-invitee", User.last.name
        assert User.last.require_2sv
      end

      should "not render 2SV form and saves invitee when invitee will be an organisation admin" do
        organisation = create(:organisation, require_2sv: false)

        post :create, params: { user: { name: "org-admin-invitee", email: "org-admin-invitee@gov.uk", organisation_id: organisation.id, role: Roles::OrganisationAdmin.role_name } }

        assert_redirected_to users_path
        assert_equal "org-admin-invitee", User.last.name
        assert User.last.require_2sv
      end

      should "not render 2SV form and saves invitee when invitee will be a super organisation admin" do
        organisation = create(:organisation, require_2sv: false)

        post :create, params: { user: { name: "super-org-admin-invitee", email: "super-org-admin-invitee@gov.uk", organisation_id: organisation.id, role: Roles::SuperOrganisationAdmin.role_name } }

        assert_redirected_to users_path
        assert_equal "super-org-admin-invitee", User.last.name
        assert User.last.require_2sv
      end

      should "re-render form and not save invitee if there are validation errors" do
        post :create, params: { user: { name: "invitee-without-email", email: "" } }

        assert_template :new
        assert_not User.exists?(name: "invitee-without-email")
      end

      should "record account invitation in event log when invitation sent" do
        EventLog.expects(:record_account_invitation).with(instance_of(User), @inviter)

        post :create, params: { user: { name: "invitee", email: "invitee@gov.uk" } }
      end

      should "not record account invitation in event log when invitation not sent because of validation errors" do
        EventLog.expects(:record_account_invitation).never

        post :create, params: { user: { name: "invitee-without-email", email: "" } }
      end

      should "not record account invitation in event log when invitation not sent because user already exists" do
        existing_user = create(:user)

        EventLog.expects(:record_account_invitation).never

        post :create, params: { user: { name: existing_user.name, email: existing_user.email } }
      end
    end
  end

  context "POST resend" do
    context "when inviter is not signed in" do
      should "require inviter to be signed in" do
        user_to_resend_for = create(:user)
        post :resend, params: { id: user_to_resend_for.id }

        assert_redirected_to new_user_session_path
      end
    end

    context "when inviter is signed in" do
      setup do
        sign_in create(:superadmin_user)
      end

      context "and inviter is not an admin" do
        setup do
          sign_in create(:user)
        end

        should "disallow access" do
          user_to_resend_for = create(:user)

          post :resend, params: { id: user_to_resend_for.id }

          assert_redirected_to root_path
        end
      end

      context "and inviter is an organisation admin" do
        setup do
          sign_in create(:organisation_admin_user)
        end

        should "disallow access" do
          user_to_resend_for = create(:user)

          post :resend, params: { id: user_to_resend_for.id }

          assert_redirected_to root_path
        end
      end

      context "and inviter is a super organisation admin" do
        setup do
          sign_in create(:super_organisation_admin_user)
        end

        should "disallow access" do
          user_to_resend_for = create(:user)

          post :resend, params: { id: user_to_resend_for.id }

          assert_redirected_to root_path
        end
      end

      should "resend account signup email to invitee" do
        user_to_resend_for = create(:user)
        User.any_instance.expects(:invite!).once

        post :resend, params: { id: user_to_resend_for.id }

        assert_redirected_to users_path
      end
    end
  end
end
