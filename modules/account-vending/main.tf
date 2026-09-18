resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name              = each.value.name
  email             = each.value.email
  parent_id         = each.value.parent_id
  tags              = merge(var.common_tags, each.value.tags)
  close_on_deletion = false
}
