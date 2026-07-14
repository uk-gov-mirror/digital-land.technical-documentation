---
title: Alerting and Monitoring Strategy
---

This document outlines our monitoring and alerting strategy for the **Planning Data Platform** and associated services. It ensures we are notified of issues early, helps us respond quickly to incidents, and supports our compliance with GOV.UK Service Standard.

---

## Objectives

Our monitoring and alerting aims to:

- Detect and alert on service degradation or outages
- Monitor end-to-end availability and health of services
- Track and investigate application-level errors
- Provide visibility for service performance and user impact
- Support incident response and service reviews

---

## Tools Used

| Tool               | Purpose                                                               |
|--------------------|-----------------------------------------------------------------------|
| **AWS CloudWatch** | Infrastructure and application metrics, logs, alarms, dashboards      |
| **Sentry**         | Application-level error tracking (uncaught exceptions, client errors) |
| **Slack**          | Alert delivery to engineers and service team                          |

---

## What We Monitor

### ✅ Availability and Health

- Health checks for public endpoints
- Service health checks should include critical dependencies so a service can report as degraded when it is reachable but cannot perform its core function
- Alerts for incidents affecting production (AWS alarms, Airfow alerts)
- Application health metrics
- Aiflow health metrics
- Database heath metrics

### ✅ Errors

- Sentry issues (JavaScript errors, Python exceptions & errors)
- Data processing errors (Aiflow alerts on failing DAGs)

### ✅ Usage & Saturation

- Application level requests
- Availability
- Throttled requests (e.g. Lambda, API Gateway)
- Resource saturation (CPU, memory, disk usage)

---

## Alerting Strategy

Alerts and notifications are both sent to the same slack channel (`#planning-data-platform`)

### When Do Alerts Trigger?

- A new issue is raised in sentry
- A DAG fails in airflow in production
- AWS alarm is raised in poduction (Alarms cover a very large quantity of checks)
- A github workflow fails

### When Are Notifications Raised

- Continuous deployment triggered for an application
- AWS alarms are raised in development or staging environments
- Share Github Workflow outputs (e.g. security scans)

### Escalation Procedure

Notifications do not require esculation but may be relevant for developers.

Alerts should be triaged and if neccessary riased as an incident. See our [run book](/run-book) for the incident procedure.

> 🔜 We have always had one channel for system alerts and notifications. This is  beginninng to ause confusion and other problems as aerts can be ost amungst notifications and notifications can  be treated as alerts. We should look at creating two separate channels.

---

## Dashboards and Visualisation

- **CloudWatch Dashboards:**
  - Health - aimed at devops engineers for monitoing the health  of all services
  - Services Reporting - aimed at product owners & technical lead to see how sevices are being used and how they're performing.
- **Sentry Issues:**
  - Latest Issues - sentry helps organise all issues raised annd we can assign them to availablle devs or holding pens

Dashboards are reviewed regularly for completeness and accuracy.

---

## Maintenance and Review

- Alert thresholds reviewed **monthly**
- Alerts reviewed **monthly**
- Dashboards rerviewed **weekly**
- Sentry issues triaged **weekly**

---

## Known Limitations & Improvements

- ❌ Logs are only kept for 2 weeks at the moment
- ❌ AWS visibility is limited to those with access

---

## References

- [GDS Service Standard – Point 11](https://www.gov.uk/service-manual/service-standard/point-11-test-the-end-to-end-service)
- [GDS Monitoring Guide](https://www.gov.uk/service-manual/technology/monitoring-your-service)
- [Sentry Documentation](https://docs.sentry.io/)
- [AWS CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)

