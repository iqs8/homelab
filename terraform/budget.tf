# ---------- The budget: $5/month for the whole account ----------
resource "aws_budgets_budget" "monthly" {
  name         = "homelab-monthly"
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Email at $2.50 actual (early warning)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
  # Email at $5 actual (the action below also fires here)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
  # Email if AWS predicts the month will end above $5
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}

# ---------- The "off switch": a policy that blocks everything ----------
# Exists all the time, but only gets attached to the velero user when over budget.
data "aws_iam_policy_document" "deny_all" {
  statement {
    sid       = "OverBudgetDenyAll"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "over_budget_deny" {
  name        = "over-budget-deny-all"
  description = "Attached to velero by AWS Budgets when the monthly budget is exceeded"
  policy      = data.aws_iam_policy_document.deny_all.json
}

# ---------- A role AWS Budgets uses to flip the switch ----------
# AWS Budgets is a service, not a person; it needs permission to attach policies.
data "aws_iam_policy_document" "budgets_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "budgets_action" {
  name               = "budgets-action"
  assume_role_policy = data.aws_iam_policy_document.budgets_assume.json
}

resource "aws_iam_role_policy_attachment" "budgets_action" {
  role       = aws_iam_role.budgets_action.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBudgetsActionsWithAWSResourceControlAccess"
}

# ---------- The action: over $5 actual → attach deny-all to velero ----------
resource "aws_budgets_budget_action" "cut_off_velero" {
  budget_name        = aws_budgets_budget.monthly.name
  action_type        = "APPLY_IAM_POLICY"
  approval_model     = "AUTOMATIC" # no "are you sure?" email; it just happens
  notification_type  = "ACTUAL"
  execution_role_arn = aws_iam_role.budgets_action.arn

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100
  }

  definition {
    iam_action_definition {
      policy_arn = aws_iam_policy.over_budget_deny.arn
      users      = [aws_iam_user.velero.name]
    }
  }

  subscriber {
    address           = var.budget_email
    subscription_type = "EMAIL"
  }
}