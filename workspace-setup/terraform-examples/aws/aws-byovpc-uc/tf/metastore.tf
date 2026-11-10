# Unity Catalog metastore: this template only ASSIGNS the workspace to an existing metastore.
#
# A metastore is an account-level, regional resource shared by every workspace in that region
# (one metastore per region per account). It must not share a Terraform state with a single
# workspace, otherwise `terraform destroy` of the workspace could delete it. Create it once in
# the account console (or in a separate Terraform stack) and pass its ID in `metastore_id`, or
# leave `metastore_id` empty to auto-discover the metastore in `var.region`.

# Older versions of this template created `databricks_metastore.metastore` in this state.
# Forget it instead of destroying it when upgrading (requires Terraform >= 1.7).
removed {
  from = databricks_metastore.metastore

  lifecycle {
    destroy = false
  }
}

# Auto-discovery: list every metastore in the account (name => id) when no ID is given.
data "databricks_metastores" "all" {
  count    = var.metastore_id == "" ? 1 : 0
  provider = databricks.mws
}

locals {
  # Metastores to look up: the explicit one, or every metastore in the account.
  metastore_candidates = var.metastore_id != "" ? tomap({ (var.metastore_id) = var.metastore_id }) : (
    data.databricks_metastores.all[0].ids != null ? data.databricks_metastores.all[0].ids : tomap({})
  )
}

# Read each candidate to get its region. Both data sources are read at plan time.
data "databricks_metastore" "candidate" {
  for_each     = local.metastore_candidates
  provider     = databricks.mws
  metastore_id = each.value
}

locals {
  # Candidates in the workspace region (at most one per region per account).
  region_metastores = [
    for m in data.databricks_metastore.candidate : m if lower(m.region) == lower(var.region)
  ]
  metastore      = length(local.region_metastores) == 1 ? local.region_metastores[0] : null
  metastore_id   = local.metastore != null ? local.metastore.metastore_id : ""
  metastore_name = local.metastore != null ? local.metastore.name : ""
}

resource "databricks_metastore_assignment" "this" {
  metastore_id = local.metastore_id
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  depends_on   = [databricks_mws_workspaces.this, time_sleep.wait_2_minutes]

  lifecycle {
    precondition {
      condition     = var.metastore_id == "" || length(local.region_metastores) == 1
      error_message = "Metastore ${var.metastore_id} is not in the workspace region (${var.region}). Workspace region should match metastore region: pass the ID of the ${var.region} metastore, or leave metastore_id empty to auto-discover it."
    }
    precondition {
      condition     = var.metastore_id != "" || length(local.region_metastores) > 0
      error_message = "No Unity Catalog metastore found in region ${var.region} for this Databricks account. This template does not create metastores. Ask an account admin to create one in the account console (Catalog > Create metastore, region ${var.region}) or in a separate Terraform stack, then re-run plan with metastore_id empty (auto-discover) or set to the new metastore's ID."
    }
    precondition {
      condition     = length(local.region_metastores) <= 1
      error_message = "More than one metastore found in region ${var.region}. Set metastore_id to the one this workspace should use."
    }
  }
}
