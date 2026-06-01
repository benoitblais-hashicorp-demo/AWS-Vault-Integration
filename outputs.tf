output "dummy_random_integer" {
  description = "A dummy random integer generated to confirm the speculative run workflow execution."
  value       = random_integer.dummy.result
}