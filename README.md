# ADO Secure Runners
sample terraform to create the following architecture:

* Azure Firewall with only allowing 443 outbound
* VNET with two subnets (firewall and compute)
* Network Security Group only allowing traffic on the same vnet, from a load balancer or on 443
* Route table on the VNET so next hop traffic will go to the firewall
* VM Scale Set with az cli, terraform and kubectl preconfigured
* Managed Identity with read permissions to the resource group

![data exported from azure resource visualizer](https://raw.githubusercontent.com/implodingduck/ado-secure-runners/main/rg-ado-secure-runners.png)