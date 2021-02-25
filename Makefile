PWD = $(shell pwd)

.dockerimage: Dockerfile
	docker build -t k8s-lab-aws:deploy .
	touch .dockerimage

.PHONY: tf-plan
tf-plan: .dockerimage
	docker run -w /infra -v ${PWD}:/infra k8s-lab-aws:deploy init

.PHONY: tf-plan
tf-plan: .dockerimage
	docker run -w /infra -e AWS_PROFILE=${AWS_PROFILE} \
		-v ${PWD}:/infra \
		-v ~/.aws/credentials:/root/.aws/credentials \
		k8s-lab-aws:deploy plan -out k8s-lab-aws.tfplan

.PHONY: tf-apply
tf-apply: .dockerimage
	docker run -w /infra -e AWS_PROFILE=${AWS_PROFILE} \
		-v ${PWD}:/infra \
		-v ~/.aws/credentials:/root/.aws/credentials \
		k8s-lab-aws:deploy apply k8s-lab-aws.tfplan

.PHONY: tf-destroy
tf-destroy: .dockerimage
	docker run -w /infra -e AWS_PROFILE=${AWS_PROFILE} \
		-v ${PWD}:/infra \
		-v ~/.aws/credentials:/root/.aws/credentials \
		k8s-lab-aws:deploy destroy -auto-approve





