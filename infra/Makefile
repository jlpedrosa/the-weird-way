
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

.PHONY: connect
connect:
	ssh -o "StrictHostKeyChecking no" jose@$$(terraform output -json | jq -r '.instances.value."ctrl-plane-1".address')

.PHONY: worker
worker:
	ssh -o "StrictHostKeyChecking no" jose@$$(terraform output -json | jq -r '.instances.value."wrkr-node-1".address')


.PHONY: reset
reset: destroy apply connect