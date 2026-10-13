# About this repository
This repository contains code and solutions that I would like to share with the Oracle APEX community.

# Repository structure & modules

## Useful packages
### APEX Human Task Extension
A PL/SQL utility package extending the native `APEX_HUMAN_TASK` API. It enables administrative operations on Human Tasks by temporarily switching to a Business Administrator (BA) session, executing the requested action, and restoring the caller's original session.

Read more about [APEX Human Task Extension](./apex-human-tasks/apex-human-task-extension-pkg).