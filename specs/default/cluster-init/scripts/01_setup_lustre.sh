#!/bin/bash

# vars used in script
mdt_device=/dev/sdb1
ost_device='/dev/nvme*n1'
raid_device=/dev/md10

# set up cycle vars
yum -y install jq
cluster_name=$(jetpack config cyclecloud.cluster.name)
ccuser=$(jetpack config cyclecloud.config.username)
ccpass=$(jetpack config cyclecloud.config.password)
ccurl=$(jetpack config cyclecloud.config.web_server)
cctype=$(jetpack config cyclecloud.node.template)

storage_account=$(jetpack config lustre.blobaccount)
storage_key="$(jetpack config lustre.blobkey)"
storage_container=$(jetpack config lustre.blobcontainer)

script_dir=$CYCLECLOUD_SPEC_PATH/files
chmod +x $script_dir/*.sh

# RAID OST DEVICES
$script_dir/create_raid0.sh $raid_device $ost_device

# INSTALL LUSTRE PACKAGES
$script_dir/lfspkgs.sh

ost_index=1

if [ "$cctype" = "mds" ]; then

	# SETUP MDS
	$script_dir/lfsmaster.sh $mdt_device

else

	echo "wait for the mds to start"
	while true; do
		mds_state="$(curl -s -k --user $ccuser:$ccpass "$ccurl/clusters/$cluster_name/nodes" | jq -r '.nodes[] | select(.Template=="mds") | .State')"
		if [ "$mds_state" = "Started" ]; then
			break
		fi
		sleep 30
	done

	ccname=$(jetpack config azure.metadata.compute.name)
	ost_index=$((${ccname##*_}+2))

fi

echo "ost_index=$ost_index"

mds_ip=$(curl -s -k --user $ccuser:$ccpass "$ccurl/clusters/$cluster_name/nodes" | jq -r '.nodes[] | select(.Template=="mds") | .IpAddress')

PSSH_NODENUM=$ost_index $script_dir/lfsoss.sh $mds_ip $raid_device

$script_dir/lfshsm.sh $mds_ip $storage_account "$storage_key" $storage_container

if [ "$cctype" = "mds" ]; then

	# IMPORT CONTAINER
	$script_dir/lfsclient.sh $mds_ip
	$script_dir/lfsimport.sh $storage_account "$storage_key" $storage_container

fi

