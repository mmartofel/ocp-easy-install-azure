# Show and accept the Red Hat OpenShift Worker image terms in Azure Marketplace

# accept for US
az vm image terms show --urn redhat-limited:rh-ocp-worker:rh-ocp-worker:4.18.2026012111
az vm image terms accept --urn redhat-limited:rh-ocp-worker:rh-ocp-worker:4.18.2026012111

# accept for EMEA
az vm image terms show --urn redhat:rh-ocp-worker:rh-ocp-worker:4.18.2026012111
az vm image terms accept --urn redhat:rh-ocp-worker:rh-ocp-worker:4.18.2026012111


# Full list of available OCP worker images in Azure Marketplace
# Accept TERMS to use Red Hat image
# US
# az vm image terms accept --urn redhat:rh-ocp-worker:rh-ocp-worker:4.18.2026012111 -o table
# az vm image terms accept --urn redhat:rh-opp-worker:rh-ocp-worker:4.18.2026012111 -o table
# az vm image terms accept --urn redhat:rh-oke-worker:rh-ocp-worker:4.18.2026012111 -o table
# EMEA
# az vm image terms accept --urn redhat-limited:rh-ocp-worker:rh-ocp-worker:4.18.2026012111 -o table
# az vm image terms accept --urn redhat-limited:rh-opp-worker:rh-ocp-worker:4.18.2026012111 -o table
# az vm image terms accept --urn redhat-limited:rh-oke-worker:rh-ocp-worker:4.18.2026012111 -o table