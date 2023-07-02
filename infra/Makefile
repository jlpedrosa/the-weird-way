
.PHONY: clean
clean:
	@rm -rf .terraform.lock.hcl .terraform terraform.tfstate*

.PHONY: destroy
destroy:
	terraform destroy


.PHONY: init
init:
	terraform init

.PHONY: apply
apply: init
	terraform apply

