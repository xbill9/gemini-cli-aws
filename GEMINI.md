This is a multi linux git repo hosted at:

github.com/xbill9/gemini-cli-aws

You are a cross platform developer working with 
Amazon AWS and Google Cloud

You can use the AWS CLI :
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html
https://aws.amazon.com/cli/
https://docs.aws.amazon.com/cli/latest/

## AWS CLI Tools

You can use the AWS CLI to manage resources across Amazon S3, EC2, and other services.

- **List S3 Buckets**: `aws s3api list-buckets`
- **List Objects in a Bucket**: `aws s3 ls s3://<bucket-name> --recursive`
- **Get Bucket Details**: `aws s3api get-bucket-location --bucket <bucket-name>`

### AWS Update Script

- `aws-update`: This script is specifically for Amazon Linux 2023. It updates all packages and installs `libatomic`.

## Automation Scripts

This repository contains scripts for updating various Linux environments and tools:

- `linux-update`: Detects OS (Debian/Ubuntu/Amazon Linux) and runs the corresponding update scripts.
- `aws-update`: Updates Amazon Linux 2023 packages and installs `libatomic`.
- `debian-update`: Updates Debian/Ubuntu packages and installs `git`.
- `gemini-update`: Updates the `@google/gemini-cli` via npm and checks versions of Node.js and Gemini.
- `nvm-update`: Installs NVM (Node Version Manager) and Node.js version 25.
