resource "local_file" "pet" {

 filename = "/home/sri-abhi/pets.txt"
 content = "We love pets!"
 file_permission = "0700"
}
