create or replace package apex_human_task_extension_pkg
as

  -- The package is intended to be called from an active APEX session.
  -- The BA username must be configured as a Business Administrator in the task definition.
  -- APEX username configured as Business Administrator in the task definition.
  gc_ba_username constant varchar2(255) := 'TECHNICAL_HUMAN_TASK_BA_USER';

  gc_error_no_active_session constant pls_integer   := -20900;
  gc_msg_no_active_session   constant varchar2(100) := 'The package must be called from an active APEX session.';

  -- Delegates a task to a specified user.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  procedure delegate_task(
    p_task_id                    in number,
    p_to_user                    in varchar2,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null);

  -- Cancels a task.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  procedure cancel_task(
    p_task_id                    in number,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null);

  -- Adds a new potential owner to a task.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  procedure add_task_potential_owner(
    p_task_id                    in number,
    p_potential_owner            in varchar2,
    p_identity_type              in apex_human_task.t_task_identity_type default apex_human_task.c_task_identity_type_user,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null);

  -- Removes a potential owner from a task.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  procedure remove_potential_owner(
    p_task_id                    in number,
    p_potential_owner            in varchar2,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null);

  -- Sets the priority of a task.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  procedure set_task_priority(
    p_task_id                    in number,
    p_priority                   in integer,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null);

  -- Sets the due date of a task.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  procedure set_task_due(
    p_task_id                    in number,
    p_due_date                   in timestamp with time zone,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null);

  -- Renews an expired or errored task, returning the new task ID.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  function renew_task(
    p_task_id                    in number,
    p_priority                   in integer               default null,
    p_due_date                   in timestamp with time zone,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  return number;

  -- Updates the values of updatable task parameters.
  -- When p_use_business_admin_session is true, temporarily creates a BA session.
  procedure set_task_parameter_values(
    p_task_id                    in number,
    p_parameters                 in apex_human_task.t_task_parameters,
    p_raise_error                in boolean  default true,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null);

end apex_human_task_extension_pkg;
/