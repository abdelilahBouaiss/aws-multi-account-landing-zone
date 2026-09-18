output "account_ids" {
  description = "Map from approved logical account keys to AWS account IDs."
  value = {
    for key, account in aws_organizations_account.this :
    key => account.id
  }
}

output "account_arns" {
  description = "Map from approved logical account keys to AWS account ARNs."
  value = {
    for key, account in aws_organizations_account.this :
    key => account.arn
  }
}
