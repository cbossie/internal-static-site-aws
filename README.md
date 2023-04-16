# internal-static-site-aws
Internal Static Site

Environment Variables for the command line
$Env:AWS_PROFILE="*profile name*"

Things You need to supply for running it
Terraform init:

Create file in the "infrastructure" directory named "config.s3.tfbacked". Populate with the following contents:

bucket="{your state bucket}"
region="{the region of your bucket/table}"
key="{state key}"
dynamodb_table="{lock table}"
profile="{profile you are using}"


Run:
terraform init -backend-config="config.s3.tfbackend"


Create a file called "terraform.tfvars"

Populate with the following


environment = "{The environment name}"
region = "{Region you are using}"
bucket_prefix = "{The spa bucket prefix}"
domain_name = "{The internal domain to be created}"
appid="{app marker}"





















































































































