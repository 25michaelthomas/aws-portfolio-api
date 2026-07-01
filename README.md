# aws-portfolio-api
A containerized Python (FastAPI) REST API running on AWS, provisioned entirely with Terraform and deployed automatically by GitHub Actions.

## Architecture
- EC2 Auto Scaling Group behind an Application Load Balancer (the API)
- RDS PostgreSQL (database)
- S3 + Lambda (event-driven file processing)
- CloudWatch (logs, alarms, dashboard)
- GitHub Actions + OIDC (keyless CI/CD that runs Terraform)

## Status
Work in progress.
