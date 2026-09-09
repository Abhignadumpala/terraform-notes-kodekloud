# Same 3 names as the Module 5.6 count lab, but typed as a set(string) —
# for_each only accepts a map or a set of strings, never a plain list.
# Start with all 3, then remove "web-prod-1" and re-run `terraform plan`
# to confirm only that one instance is touched (compare against the
# count lab's index-shifting pitfall).


variable "web_server_names" {
  description = "Names for the web server instances - for_each keys each instance by name instead of position"
  type        = set(string)
  default     = ["web-prod-1", "web-prod-2", "web-prod-3"]
}
