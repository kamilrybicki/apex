> [!NOTE]
> **Disclaimer**
> This package code and documentation were generated with the assistance of an LLM and subsequently reviewed and verified by me. The concept and architectural design are entirely my own, created to address real challenges encountered while building business applications with APEX Workflows and APEX Human Tasks.
>

# APEX Human Task Extension Package

A PL/SQL utility package extending the native `APEX_HUMAN_TASK` API. It enables administrative operations on Human Tasks by temporarily switching to a Business Administrator (BA) session, executing the requested action, and restoring the caller's original session.

## When use this package?

In Oracle APEX, administrative operations on a task require Business Administrator privileges. However, in many business workflows, you may want to grant specific operational capabilities to task participants without giving them full Business Administrator permissions over the task definition.   

**Common Use Case**:

You want to allow the current assignee of a task to add a new potential owner and delegate the task to a colleague. Standard APEX task security restricts these operations if the user is not a Business Administrator. 

This package handles that scenario by:
1. Saving the current APEX session context.
2. Creating a session for a designated technical Business Administrator account.
3. Executing the requested `APEX_HUMAN_TASK` operation.
4. Adding an audit comment to the task history (e.g., "Action DELEGATE_TASK was executed by JDOE using the technical Business Administrator account...").
5. Restoring the original user session, even if an error occurs.

## Prerequisites

- Oracle APEX 24.2 or higher. This package was developed and tested for APEX 24.2. Earlier or newer versions may require minor adjustments to match API signature changes.
- The package must be called from an active APEX session.

## Installation & Configuration

1. **Install package**

   Go to `src/` catalog and run the provided SQL scripts in your database schema your APEX application is built on:
   ```sql
   @apex_human_task_extension_pkg.pks
   @apex_human_task_extension_pkg.pkb
   ```

2. **Configure the Business Administrator**

   The package relies on a constant `gc_ba_username` (default: `TECHNICAL_HUMAN_TASK_BA_USER`). 
   - Navigate to **Shared Components > Task Definitions** in your APEX Builder.
   - Edit your Task Definition.
   - Under **Participants**, add `TECHNICAL_HUMAN_TASK_BA_USER` as a **Business Administrator**.
     - The user doesn't necessarily need to exist in the application. Whether or not they are required depends on the application and environment configuration.
   - *(Optional)* If you wish to use a different username, modify the `gc_ba_username` constant in the package specification before installing the package.


## API Reference

All procedures in this package mirror the native `APEX_HUMAN_TASK` subprograms for APEX version 24.2 but include two additional parameters:
* `p_use_business_admin_session (boolean)`: Defaults to `false` (when `false`, the package works as native). Set to `true` to execute operation using the Business Administrator session.
* `p_comment (varchar2)`: An optional comment added to the task.

### Available Subprograms
* `delegate_task`
* `cancel_task`
* `add_task_potential_owner`
* `remove_potential_owner`
* `set_task_priority`
* `set_task_due`
* `renew_task` (Function returning the new task ID)
* `set_task_parameter_values`

## Usage Example
### Adding a new potential owner and delegating a task using BA privileges
Allowing a user to add a potential owner and delegate a task to a colleague without assigning BA permissions to that user.

```sql
begin
    -- I'm logged as KRYBICKI. I'm NOT a Business Administrator for this task.

    -- Step 1: Add a new potential owner to the task using BA privileges
    apex_human_task_extension_pkg.add_task_potential_owner(
        p_task_id                    => :P1_TASK_ID,
        p_potential_owner            => 'JSMITH',
        p_use_business_admin_session => true,
        p_comment                    => 'Adding John as a potential owner for task re-assignment.'
    );

    -- Step 2: Delegate the task to the newly added potential owner using BA privileges
    apex_human_task_extension_pkg.delegate_task(
        p_task_id                    => :P1_TASK_ID,
        p_to_user                    => 'JSMITH',
        p_use_business_admin_session => true,
        p_comment                    => 'Delegating task to John for review.'
    );
end;
```
*Result*: `JSMITH` is added as a potential owner and the task is delegated to him. The task history logs audit comments for both operations, recording that the current user executed these actions using the technical account.

## Exception Handling & Security
- **Session Restoration:** The original APEX session is restored via `restore_session_after_error` if an operation fails, preventing dropped session states.
- **Audit Trail:** Automatic comments capture the actual `APP_USER` username when using the BA account, preserving accountability in task history.

## Contributing
Contributions are welcome! Feel free to submit issues or pull requests to improve the package.

## License
This project is licensed under the MIT License - see the LICENSE file for details.