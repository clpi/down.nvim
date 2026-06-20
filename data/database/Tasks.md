---
title: Tasks
type: database
database:
  description:
    type: text
  due_date:
    type: date
  priority:
    type: select
    options:
      - Low
      - Medium
      - High
      - Urgent
  status:
    type: select
    options:
      - Backlog
      - Todo
      - In Progress
      - Done
  tags:
    type: multi_select
  title:
    type: title
---

| description | due_date | priority | status | tags | title |
| --- | --- | --- | --- | --- | --- |
|  | 2026-06-20 | Medium | Todo |  | Tasks |
