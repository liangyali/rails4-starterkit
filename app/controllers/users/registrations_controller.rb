class Users::RegistrationsController < Devise::RegistrationsController
  before_action :permit_params, only: :create
  after_action :cleanup_oauth, only: [:create, :update]

  # Additional resource fields to permit
  # Devise already permits email, password, etc.
  SANITIZED_PARAMS = [:first_name, :last_name].freeze

  # GET /resource/sign_up
  def new
    super
  end

  # GET /resource/after
  # Redirect user here after login or signup action
  # Used to require additional info from the user like email address, agree to new TOS, etc.
  def after_auth
    # User should either be...
    # already signed in by Devise
    # or in process of signing up via OAuth provider
    if signed_in?
      authenticate_scope!
    else
      build_resource({})
    end
    if !signed_in? && @auth.blank?
      # Something went wrong with OmniAuth, redirect user back to sign up page
      redirect_to new_user_registration_path
    elsif resource.persisted? && resource.valid?
      # Everything is good, send user on his/her way
      path = stored_location_for(current_user)
      path ||= user_home_path
      redirect_to path
    else
      # User needs to update some info before proceeding
      respond_with(resource, template: 'users/auth/interrupt', auth: @auth)
    end
  end

  # POST /resource
  def create
    super
    @auth.save! if @auth.present? && resource.persisted?
  rescue ActiveRecord::ActiveRecordError => e
    resource.destroy
    sign_out(resource) if signed_in?
    report_error(e)
    flash.clear
    flash[:error] = I18n.t 'errors.unknown'
    redirect_to error_page_path
  end

  # GET /resource/edit
  def edit
    super
  end

  # PUT /resource
  def update
    super
  end

  # DELETE /resource
  def delete
    super
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  def cancel
    super
  end

  protected

  def permit_params
    devise_parameter_sanitizer.for(:sign_up) << SANITIZED_PARAMS
  end

  def build_resource(*args)
    super
    @auth = nil
    if session[:omniauth].present?
      @auth = Authentication.build_from_omniauth(session[:omniauth])
      resource.authentications << @auth
      resource.reverse_merge_attributes_from_auth(@auth)
    end
    resource
  end

  # Clear out omniauth session to prevent session bloat
  def cleanup_oauth
    session.delete(:omniauth) if resource.persisted?
  end

  def after_sign_up_path_for(resource)
    path = after_sign_in_path_for(resource)
    if path == user_root_path
      user_root_path resource.id
    else
      user_root_path resource.id, path: path
    end
  end
end
