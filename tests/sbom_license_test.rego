package main

import rego.v1

test_allow_clean_sbom if {
	res := deny with input as {
		"bomFormat": "CycloneDX",
		"components": [{
			"name": "express",
			"version": "4.18.2",
			"licenses": [{"license": {"id": "MIT"}}],
		}],
	}
	count(res) == 0
}

test_deny_gpl_license if {
	res := deny with input as {
		"bomFormat": "CycloneDX",
		"components": [{
			"name": "gpl-math-lib",
			"version": "1.0.0",
			"licenses": [{"license": {"id": "GPL-3.0"}}],
		}],
	}
	count(res) == 1
}
