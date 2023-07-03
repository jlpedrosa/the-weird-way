
.PHONY: clean
clean:
	@rm -rf .terraform.lock.hcl .terraform terraform.tfstate*

.PHONY: destroy
destroy:
	terraform apply -destroy -auto-approve -parallelism=50


.PHONY: init
init:
	terraform init

.PHONY: apply
apply: init
	terraform apply -auto-approve -parallelism=50

