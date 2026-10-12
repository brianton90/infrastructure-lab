# -----------------------------------------------------------------------
# Budget — immediate alert if any cost appears on the tenancy.
# Triggers at 1% of a $1 budget, meaning any charge at all.
# This is a warning system — OCI does not automatically block spending.
# -----------------------------------------------------------------------

resource "oci_budget_budget" "zero_cost_guard" {
  compartment_id = var.tenancy_ocid
  amount         = 1
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_ocid]
  display_name   = "always-free-lab-zero-cost-guard"
}

resource "oci_budget_alert_rule" "zero_cost_alert" {
  budget_id      = oci_budget_budget.zero_cost_guard.id
  type           = "ACTUAL"
  threshold      = 1
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  display_name   = "alert-if-any-spend"
  message        = "Warning: a charge was detected in the Always Free lab compartment."
}
