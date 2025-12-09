🛠️ Red Hat OpenShift Easy Install on Azure

OCP Easy Install on Azure is a set of scripts that automate the installation of OpenShift 4.x clusters on Microsoft Azure.
It simplifies the setup process by handling Azure VM size selection, pull secrets, SSH keys, Azure authentication, DNS zone detection, and generating the OpenShift install-config.yaml.

💡 Features

✅ Automatic detection of Azure subscription, tenant, and region

✅ Automatic detection of Azure DNS base domain

✅ Pre-flight checks for openshift-install, Azure credentials, SSH keys, and pull secrets

✅ Interactive selection of master and worker VM sizes

✅ Easy selection of OpenShift versions from the stable channel

✅ Automatic generation of install-config.yaml with all required fields

✅ Optional release image override with architecture detection

✅ Fully colorful and user-friendly output with icons

⚙️ Requirements

Bash 3+

Azure CLI installed and authenticated (az login)

Or exported service principal credentials:

export AZURE_SUBSCRIPTION_ID=xxxx
export AZURE_TENANT_ID=xxxx
export AZURE_CLIENT_ID=xxxx
export AZURE_CLIENT_SECRET=xxxx


OpenShift Installer (matching desired OpenShift version)

Pull secret file from Red Hat OpenShift

SSH key for cluster access (or you can generate it yourself)

If you miss anything, you will be guided by error-handling messages.

🚀 Installation Steps

Clone the repository:

git clone https://github.com/mmartofel/ocp_easy_install_azure.git
cd ocp_easy_install_azure


Set optional environment variables:

export CLUSTER_NAME=zenek
export CLUSTER_DIR=./config
export BASE_DOMAIN=example.com
export AZURE_REGION=eastus


or do nothing and stay with default values set inside install.sh.

Run the installation script:

./install.sh


Follow the interactive prompts to choose master and worker VM sizes, and OpenShift version.
The script will generate install-config.yaml and start the cluster installation.
At the end of the installation you will see all required details to connect and use your newly installed Red Hat OpenShift cluster. Enjoy!

Access your cluster:

For example using oc CLI:

export KUBECONFIG=./config/auth/kubeconfig
oc status


or via browser — the URL and credentials are printed at the end of installation.

🗂️ Directory Structure
.
├── install.sh                # Main installation script
├── instances/                # VM size definitions
│   ├── master
│   └── worker
├── pull-secret.txt           # OpenShift pull secret (user-provided)
├── ssh/                      # SSH key for nodes
│   └── id_rsa.pub
└── config/                   # Generated OpenShift config directory
    └── install-config.yaml

🖌️ Customization

You can modify:

./instances/master
./instances/worker


to update available Azure VM sizes.
I provided a few commonly used ones, but feel free to add any sizes appropriate for your cluster.

This is also a great place to define GPU-enabled VM types if you'd like to experiment with Red Hat OpenShift AI.

⚠️ Notes

The installer supports automatic OpenShift version selection from the stable channel (e.g., stable-4.20).
You can modify your channel over time or propose improvements to this functionality.

The script includes pre-flight checks to prevent common errors.

A custom release image override is used to start from the most recent or purposely selected patch version to save time on post-install upgrade chains.

📖 References

OpenShift Installation Guide
Azure OpenShift Installer Documentation

🤝 Contributing

Feel free to submit issues, pull requests, or suggest new features.
This project is meant to simplify Red Hat OpenShift installations on Azure for all users and is community-driven.

⚡ License

This repository is licensed under the MIT License. See LICENSE for details.# ocp-easy-install-azure
