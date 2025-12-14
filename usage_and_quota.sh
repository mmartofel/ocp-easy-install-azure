# Customize the following line to choose your Azure region to install OCP cluster in

LOCATION=polandcentral                 # the location of your cluster

az vm list-usage --location ${LOCATION} --out table | grep "Total Regional vCPUs"
az vm list-usage --location ${LOCATION} --out table | grep "Standard DSv3 Family vCPUs"
