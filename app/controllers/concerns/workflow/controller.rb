module Workflow
  # Contains workflow related behaviour for the `ProjectsController` controller.
  module Controller
    extend ActiveSupport::Concern

    included do
      load_resource :state, only: :transition, class: 'Workflow::State', id_param: :state

      # We can't use the :yubikey_protected macro because NdrAuthenticate doesn't currently
      # allow for conditional challenges, nor are any serialized params restored until later
      # in the process. We'll work around that for now...
      before_action :restore_params,    only: :transition, prepend: true
      before_action :challenge_yubikey, only: :transition, if: :yubikey_protected_transition?

      after_action :allocate_project, only: :transition
    end

    # PATCH
    # Initiates a change to a project's state.
    # `ProjectsController` should already be loading/authorizing the `Project` resource.
    def transition
      @project.transition_to(@state, current_user) do |project, project_state|
        authorize!(:create, project_state)
        project.assign_attributes(transition_params)

        if temporally_assigned_user
          project_state.assign_to!(
            user: temporally_assigned_user,
            assigning_user: current_user
          )
        end

        # NOTE: Meh. Rather than adding and drilling through layers of nested attributes we'll
        # redirect the comment attributes onto the `project_state` object instead.
        project_state.assign_attributes(comment_params)
      end

      if @project.current_state.id.in? %w[DPIA_REJECTED DPIA_MODERATION]
        ProjectsNotifier.project_dpia_updated(
          project: @project,
          status: @project.current_state.id,
          user_to_notify: temporally_assigned_user || @project.assigned_user,
          comment: comment_params[:body]
        )
      end

      redirect_to @project
    end

    private

    def transition_params
      params.fetch(:project, {}).permit(:closure_reason_id)
    end

    def comment_params
      return {} unless params.dig(:project, :comments_attributes, '0')

      params.fetch(:project).permit(comments_attributes: %i[body]).tap do |object|
        object[:comments_attributes]['0'][:user] = current_user
      end
    end

    def temporally_assigned_user
      return unless id ||= params.dig(:project, :project_state, :assigned_user_id)

      @temporally_assigned_user ||=
        User.all_application_managers.in_use.where.not(id: current_user).find_by(id: id)
    end

    def allocate_project
      return unless @project.current_state.id == 'SUBMITTED'

      Projects::ApplicationManagerAllocatorService.call(project: @project)
    end

    def yubikey_protected_transition?
      return false if Rails.env.development?

      @project.current_state.
        transitions.
        applicable_to(@project.project_type).
        find_by(next_state: @state)&.
        requires_yubikey?
    end
  end
end
