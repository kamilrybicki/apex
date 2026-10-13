create or replace package body apex_human_task_extension_pkg
as

  type t_session_context is record(
    original_app_id       number,
    original_page_id      number,
    original_session_id   number,
    has_original_session  boolean,
    ba_session_id         number);

  -- Creates a temporary APEX session for the configured BA user.
  procedure create_ba_session(
    p_session_context out t_session_context)
  as
  begin
    p_session_context.original_app_id := nv('APP_ID');
    p_session_context.original_page_id := nv('APP_PAGE_ID');
    p_session_context.original_session_id := nv('APP_SESSION');
    p_session_context.has_original_session :=
      p_session_context.original_session_id is not null
      and p_session_context.original_session_id > 0;
    p_session_context.ba_session_id := null;

    if p_session_context.original_app_id is null
       or p_session_context.original_page_id is null then
      raise_application_error(
        gc_error_no_active_session,
        gc_msg_no_active_session);
    end if;

    apex_session.create_session(
      p_app_id   => p_session_context.original_app_id,
      p_page_id  => p_session_context.original_page_id,
      p_username => gc_ba_username);

    p_session_context.ba_session_id := nv('APP_SESSION');

  exception
    when others then
      raise;
  end create_ba_session;

  -- Restores the original APEX session and removes the temporary BA session.
  procedure restore_session(
    p_session_context in t_session_context)
  as
  begin
    apex_session.detach;

    if p_session_context.ba_session_id is not null then
      apex_session.delete_session(
        p_session_id => p_session_context.ba_session_id);
    end if;

    if p_session_context.has_original_session then
      apex_session.attach(
        p_app_id     => p_session_context.original_app_id,
        p_page_id    => p_session_context.original_page_id,
        p_session_id => p_session_context.original_session_id);
    end if;
  exception
    when others then
      raise;
  end restore_session;

  -- Adds an audit comment for an operation executed through the BA session.
  procedure add_audit_comment(
    p_task_id      in number,
    p_actual_user  in varchar2,
    p_operation    in varchar2,
    p_comment      in varchar2 default null)
  as
    l_text varchar2(4000);
  begin
    l_text := 'Action ' || p_operation
           || ' was executed by ' || nvl(p_actual_user, 'UNKNOWN')
           || ' using the technical Business Administrator account ('
           || gc_ba_username || ').';

    if p_comment is not null then
      l_text := substr(l_text || ' Comment: ' || p_comment, 1, 4000);
    end if;

    apex_human_task.add_task_comment(
      p_task_id => p_task_id,
      p_text    => l_text);
  exception
    when others then
      raise;
  end add_audit_comment;

  -- Adds a regular comment or a bypass audit comment to the task.
  procedure add_operation_comment(
    p_task_id                    in number,
    p_actual_user                in varchar2,
    p_operation                  in varchar2,
    p_use_business_admin_session in boolean,
    p_comment                    in varchar2)
  as
  begin
    if p_use_business_admin_session then
      add_audit_comment(
        p_task_id     => p_task_id,
        p_actual_user => p_actual_user,
        p_operation   => p_operation,
        p_comment     => p_comment);
    elsif p_comment is not null then
      apex_human_task.add_task_comment(
        p_task_id => p_task_id,
        p_text    => substr(p_comment, 1, 4000));
    end if;
  exception
    when others then
      raise;
  end add_operation_comment;

  -- Restores the caller session while preserving the original operation error.
  procedure restore_session_after_error(
    p_session_context in t_session_context)
  as
  begin
    restore_session(p_session_context);
  exception
    when others then
      -- Do not mask the original operation error with a restore session error.
      null;
  end restore_session_after_error;

  -- Delegates a task to a specified user with an optional BA session bypass.
  procedure delegate_task(
    p_task_id                    in number,
    p_to_user                    in varchar2,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_actual_user     varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    apex_human_task.delegate_task(
      p_task_id => p_task_id,
      p_to_user => p_to_user);

    if p_use_business_admin_session then
      add_operation_comment(p_task_id, l_actual_user, 'DELEGATE_TASK', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(p_task_id, null, 'DELEGATE_TASK', p_use_business_admin_session, p_comment);
    end if;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end delegate_task;

  -- Cancels a task with an optional BA session bypass.
  procedure cancel_task(
    p_task_id                    in number,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_actual_user     varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    apex_human_task.cancel_task(
      p_task_id => p_task_id);

    if p_use_business_admin_session then
      add_operation_comment(p_task_id, l_actual_user, 'CANCEL_TASK', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(p_task_id, null, 'CANCEL_TASK', p_use_business_admin_session, p_comment);
    end if;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end cancel_task;

  -- Adds a potential owner with an optional BA session bypass.
  procedure add_task_potential_owner(
    p_task_id                    in number,
    p_potential_owner            in varchar2,
    p_identity_type              in apex_human_task.t_task_identity_type default apex_human_task.c_task_identity_type_user,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_actual_user     varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    apex_human_task.add_task_potential_owner(
      p_task_id         => p_task_id,
      p_potential_owner => p_potential_owner,
      p_identity_type   => p_identity_type);

    if p_use_business_admin_session then
      add_operation_comment(p_task_id, l_actual_user, 'ADD_TASK_POTENTIAL_OWNER', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(p_task_id, null, 'ADD_TASK_POTENTIAL_OWNER', p_use_business_admin_session, p_comment);
    end if;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end add_task_potential_owner;

  -- Removes a potential owner with an optional BA session bypass.
  procedure remove_potential_owner(
    p_task_id                    in number,
    p_potential_owner            in varchar2,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_actual_user     varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    apex_human_task.remove_potential_owner(
      p_task_id         => p_task_id,
      p_potential_owner => p_potential_owner);

    if p_use_business_admin_session then
      add_operation_comment(p_task_id, l_actual_user, 'REMOVE_POTENTIAL_OWNER', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(p_task_id, null, 'REMOVE_POTENTIAL_OWNER', p_use_business_admin_session, p_comment);
    end if;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end remove_potential_owner;

  -- Sets task priority with an optional BA session bypass.
  procedure set_task_priority(
    p_task_id                    in number,
    p_priority                   in integer,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_actual_user     varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    apex_human_task.set_task_priority(
      p_task_id  => p_task_id,
      p_priority => p_priority);

    if p_use_business_admin_session then
      add_operation_comment(p_task_id, l_actual_user, 'SET_TASK_PRIORITY', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(p_task_id, null, 'SET_TASK_PRIORITY', p_use_business_admin_session, p_comment);
    end if;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end set_task_priority;

  -- Sets task due date with an optional BA session bypass.
  procedure set_task_due(
    p_task_id                    in number,
    p_due_date                   in timestamp with time zone,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_actual_user     varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    apex_human_task.set_task_due(
      p_task_id  => p_task_id,
      p_due_date => p_due_date);

    if p_use_business_admin_session then
      add_operation_comment(p_task_id, l_actual_user, 'SET_TASK_DUE', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(p_task_id, null, 'SET_TASK_DUE', p_use_business_admin_session, p_comment);
    end if;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end set_task_due;

  -- Renews an expired or errored task with an optional BA session bypass.
  function renew_task(
    p_task_id                    in number,
    p_priority                   in integer               default null,
    p_due_date                   in timestamp with time zone,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  return number
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_new_task_id    number;
    l_actual_user    varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    l_new_task_id := apex_human_task.renew_task(
      p_task_id  => p_task_id,
      p_priority => p_priority,
      p_due_date => p_due_date);

    if p_use_business_admin_session then
      add_operation_comment(l_new_task_id, l_actual_user, 'RENEW_TASK', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(l_new_task_id, null, 'RENEW_TASK', p_use_business_admin_session, p_comment);
    end if;

    return l_new_task_id;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end renew_task;

  -- Updates updatable task parameter values with an optional BA session bypass.
  procedure set_task_parameter_values(
    p_task_id                    in number,
    p_parameters                 in apex_human_task.t_task_parameters,
    p_raise_error                in boolean  default true,
    p_use_business_admin_session in boolean  default false,
    p_comment                    in varchar2 default null)
  as
    l_session_context t_session_context;
    l_session_created boolean := false;
    l_actual_user     varchar2(255);
  begin
    if p_use_business_admin_session then
      l_actual_user := v('APP_USER');
      create_ba_session(l_session_context);
      l_session_created := true;
    end if;

    apex_human_task.set_task_parameter_values(
      p_task_id     => p_task_id,
      p_parameters  => p_parameters,
      p_raise_error => p_raise_error);

    if p_use_business_admin_session then
      add_operation_comment(p_task_id, l_actual_user, 'SET_TASK_PARAMETER_VALUES', p_use_business_admin_session, p_comment);
      restore_session(l_session_context);
    elsif p_comment is not null then
      add_operation_comment(p_task_id, null, 'SET_TASK_PARAMETER_VALUES', p_use_business_admin_session, p_comment);
    end if;
  exception
    when others then
      if l_session_created then
        restore_session_after_error(l_session_context);
      end if;
      raise;
  end set_task_parameter_values;

end apex_human_task_extension_pkg;
/
