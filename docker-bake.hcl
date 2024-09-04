group "ci_targets" {
  targets = ["argon_one_fan"]
}
target "ci_platforms" {
	platforms = ["linux/arm64"]
}

target "docker-metadata-action" {}

group "default" {
  targets = ["argon_one_fan"]
}

target "argon_one_fan-local" {
  tags = ["argon_one_fan:local"]
}

target "argon_one_fan" {
	inherits = ["argon_one_fan-local", "ci_platforms", "docker-metadata-action"]
	context = "argon_one_fan"
	dockerfile = "Dockerfile"
}