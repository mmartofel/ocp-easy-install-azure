# 🛠️ Red Hat OpenShift Easy Install on Azure #

[![GitHub Repo](https://img.shields.io/badge/GitHub-mmartofel-blue)](https://github.com/mmartofel)
[![OpenShift Ready](https://img.shields.io/badge/OpenShift-Ready-brightgreen)](https://www.openshift.com)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

**OCP Easy Install on Azure** is a set of scripts that automate the installation of **OpenShift 4.x** clusters on **Microsoft Azure**.
It simplifies the setup process by handling Azure VM size selection, pull secrets, SSH keys, Azure authentication, DNS zone detection, and generating the OpenShift `install-config.yaml`.

--- 

## 💡 Features

- ✅ Automatic detection of Azure subscription, tenant, and region
- ✅ Automatic detection of Azure DNS base domain
- ✅ Pre-flight checks for openshift-install, Azure credentials, SSH keys, and pull secrets
- ✅ Interactive selection of master and worker VM sizes
- ✅ Easy selection of OpenShift versions from the stable channel
- ✅ Automatic generation of install-config.yaml with all required fields
- ✅ Optional release image override with architecture detection
- ✅ Fully colorful and user-friendly output with icons

## ⚙️ Requirements

- Bash 3+  
- Azure CLI (az) configured with appropriate credentials  
- OpenShift Installer (matching desired OpenShift version, for the time of creation of that repo 4.20)  
- Pull secret file from [Red Hat OpenShift](https://cloud.redhat.com/openshift/install)  
- SSH key for cluster access (or you can generate it with ./ssh/gen.sh)

if you missed anything you will be guided by error handling messages

## 🚀 Installation Steps ##

1. **Clone the repository:**

```bash
git clone https://github.com/mmartofel/ocp_easy_install_azure.git
cd ocp_easy_install_azure
```

2. **Set optional environment variables:**

At the file env.sh you can set following variables:

```bash
CLUSTER_DIR=config
CLUSTER_NAME=zenek
BASE_DOMAIN=example.com
PULL_SECRET_FILE=./pull-secret.txt
SSH_KEY_FILE=./ssh/id_rsa.pub
```

then just source it:

```bash
. ./env.sh
```

or do nothing and stay with default values set inside install.sh.

3. **Run the installation script:**

Run cluster installation script and foollow instructions to provide a proper parameters and credentials:

```bash
./02_install_cluster.sh
```

![alt text](./images/install.png)

Follow the interactive prompts to choose master and worker VM sizes, and OpenShift version.
The script will generate install-config.yaml and start the cluster installation.
At the end of the installation you will see all required details to connect and use your newly installed Red Hat OpenShift cluster. Enjoy!

4. **Access your cluster:**

for example using oc CLI

```bash
export KUBECONFIG=./config/auth/kubeconfig
oc status
```

or via brawser as of an info passed at the end of paragraph 4 

## 🗂️ Directory Structure

```graphql
.
├── install.sh                # Main installation script
├── instances/                # Instance type definitions
│   ├── master
│   └── worker
├── pull-secret.txt           # OpenShift pull secret (user-provided)
├── ssh/                      # SSH key for nodes
│   └── id_rsa.pub
└── config/                   # Generated OpenShift config directory
    └── install-config.yaml
```

## 🖌️ Customization

You can modify:

```bash
./instances/master
./instances/worker
```

files content to update available Azure instance types, I just provided a few tested, feel free to put your own you need at your cluster.

Here is a great place to use GPU equited instances to start your jouney with AI, best would be Red Hat OpenShift AI ;-)

## 🖌️ Uninstall your cluster

If you don't need your cluster anymore, simply delete it:

```bash
./03_uninstall_cluster.sh
```

## ⚠️ Notes

The installer supports automatic OpenShift version selection from the stable channel (e.g., stable-4.20). You can modify your channel over time, or propose how can we improve that functionality together.

The script includes pre-flight checks to prevent common errors.

Custom release image override is used to start from most recent or just purposly chosen patch version at the start to save time for 'after install' upgrades chain.

## 📖 References

OpenShift Installation Guide

Azure OpenShift Installer

## 🤝 Contributing

Feel free to submit issues, pull requests, or suggest new features.
This project is meant to simplify Red Hat OpenShift installations on Azure for any users and is community-driven.

## ⚡ License

This repository is licensed under the MIT License. See LICENSE for details.