# Start with 3 names, then remove the first one ("web-prod-1") to trigger
# the index-shifting pitfall from the module notes — terraform plan should
# show web[0] and web[1] being updated in place (their Name tag shifts to
# the next name in the list), and web[2] being destroyed.
variable "web_server_names" {
  description = "Names for the web server instances - count is driven by the length of this list"
  type        = list(string)
  default     = ["web-prod-2", "web-prod-3"]
}
