# Show and accept the Red Hat OpenShift Worker image terms in Azure Marketplace

# accept for US
az vm image terms show --urn redhat-limited:rh-ocp-worker:rh-ocp-worker:4.18.2025112710
az vm image terms accept --urn redhat-limited:rh-ocp-worker:rh-ocp-worker:4.18.2025112710

# accept for EMEA
az vm image terms show --urn redhat:rh-ocp-worker:rh-ocp-worker:4.18.2025112710
az vm image terms accept --urn redhat:rh-ocp-worker:rh-ocp-worker:4.18.2025112710