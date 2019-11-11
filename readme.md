# Azure CycleCloud Lustre

Create a lustre file system on Azure using Azure CycleCloud and cluster-init scripts.

* Set up specifically for the Lv2 VM type on Azure (2TB NVME per 8 cores)
* All nodes perform OSS and HSM - including the MDS
* All NVME disks are automatically RAIDed and used as the OST
* The internal SSD is used for the MDT

> Note: The Lustre configuration scripts are from [here](https://github.com/Azure/azurehpc/tree/master/scripts) and the Azure CycleCloud template configuration from [here](https://github.com/hmeiland/cyclecloud-lustre).

# Installation

Below are instructions to check out the project from github and add the lfs project and template:

```
git clone https://github.com/edwardsp/cyclecloud-lfs.git
cd cyclecloud-lfs
cyclecloud project upload <container>
cyclecloud import_template -f templates/lfs.txt
```

An extended PBSpro template is included in this repository with the option for choose a Lustre filesystem to set up and mount on the nodes:

```
cyclecloud import_template -f templates/pbspro.txt
```

> Note: The PBSpro template a modified version of the official one [here](https://github.com/Azure/cyclecloud-pbspro/blob/master/templates/pbspro.txt)

Now, you should be able to create a new "lfs" cluster in the Azure CycleCloud User Interface.  Once this has been created you can create PBS cluster and, in the configuration, select the new file system to be used.

# Extending a template to use a Lustre filesystem

The node types only need the following additions:

```
[[[configuration]]]
lustre.client.cluster_name = $LustreClusterName
lustre.client.mount_point = $LustreMountPoint

[[[cluster-init lfs:client]]]
```

The two variables, `LustreClusterName` and `LustreMountPoint` can be parameterized with the following option settings:

```
[[parameters Lustre Settings]]        
Order = 25
Description = "Use a Lustre cluster as a NAS. Settings for defining the Lustre cluster"

    [[[parameter LustreClusterName]]]
    Label = Lustre Cluster
    Description = Name of the Lustre cluster to connect to. This cluster should be orchestrated by the same CycleCloud Server
    Required = True
    Config.Plugin = pico.form.QueryDropdown
    Config.Query = select ClusterName as Name from Cloud.Node where Cluster().IsTemplate =!= True && ClusterInitSpecs["lfs:default"] isnt undefined
    Config.SetDefault = false

    [[[parameter LustreMountPoint]]]
    Label = Lustre MountPoint
    Description = The mount point to mount the Lustre file server on.
    DefaultValue = /lustre
    Required = True
```

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.