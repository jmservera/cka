# CKA study helpers

In this repo I'm taking all my notes and I also provide some scripts to run a VM with 
[kind](https://kind.sigs.k8s.io/) and [vscode server](https://code.visualstudio.com/docs/remote/vscode-server)

This is not a guide, just my personal notes and exercises while studying for the CKA exam.

## Components

* Infra: scripts to deploy the VM
* kind: scripts to install all you need to run kind and vscode remotely on a VM
* deployments: example deployments from the course

## Install

Provide a token file that contains your security token (can be anything, by default a uuid will be created if you don't provide one) and run the installer. It will create an Azure VM with two NICs, one for the vscode server, with an IP and dns name, and another NIC for accessing the kind services.

Once installed you can access by using the url: https://[NAME].[REGION].cloudapp.azure.com/?token=[TOKEN]



## How to use it

The main access to this solution will be via 
Once installed, you will have a Kubernetes IN Docker setup, with 1 master node and 3 workers. As every node runs inside a container, you can access the nodes by just opening a console on vscode.

### How to acccess the nodes

You can run any command on a node using docker to execute it, for example, for getting a bash for the control-plane you would run:

```bash
docker exec -it secondkind-control-plane /bin/bash
```

Like this:
![alt text](images/docker-exec.png)

# CKA studying exercises



## Infra setup

I've created a script to set up the infrastructure for my Kubernetes cluster using Azure. The script creates virtual machines (VMs) for the master and worker nodes, along with necessary networking components.

Some references:
* https://cloudinfrastructureservices.co.uk/setup-kubernetes-cluster-on-azure-self-hosted/
* https://saraswathilakshman.medium.com/setting-up-a-kubernetes-cluster-using-azure-vms-and-kubeadm-bc306ea6be90
* https://blog.nillsf.com/index.php/2021/10/29/setting-up-kubernetes-on-azure-using-kubeadm/
* https://github.com/torosgo/kubernetes-azure-kubeadm