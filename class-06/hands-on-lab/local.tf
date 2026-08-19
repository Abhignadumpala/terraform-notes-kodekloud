resource "local_file" "pet" {
  filename        = var.filename
  content         = var.content
  file_permission = var.file_permission
}
