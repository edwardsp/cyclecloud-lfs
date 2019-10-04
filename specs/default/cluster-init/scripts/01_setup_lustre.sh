#!/bin/bash

mdt_device=/dev/sdb1
ost_device=/dev/nvme0n1

cat << EOF >/etc/yum.repos.d/LustrePack.repo
[lustreserver]
name=lustreserver
baseurl=https://downloads.whamcloud.com/public/lustre/latest-2.10-release/el7.6.1810/patchless-ldiskfs-server/
enabled=1
gpgcheck=0

[e2fs]
name=e2fs
baseurl=https://downloads.whamcloud.com/public/e2fsprogs/latest/el7/
enabled=1
gpgcheck=0

[lustreclient]
name=lustreclient
baseurl=https://downloads.whamcloud.com/public/lustre/latest-2.10-release/el7.6.1810/client/
enabled=1
gpgcheck=0
EOF

yum -y install lustre kmod-lustre-osd-ldiskfs lustre-osd-ldiskfs-mount lustre-resource-agents e2fsprogs lustre-tests

sed -i 's/ResourceDisk\.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf

systemctl restart waagent

weak-modules --add-kernel --no-initramfs

umount /mnt/resource

yum -y install jq

cluster_name=$(jetpack config cyclecloud.cluster.name)

ccuser=$(jetpack config cyclecloud.config.username)
ccpass=$(jetpack config cyclecloud.config.password)
ccurl=$(jetpack config cyclecloud.config.web_server)
cctype=$(jetpack config cyclecloud.node.template)

ost_index=1

if [ "$cctype" = "mds" ]; then

	echo "setting up the mds"

	mkfs.lustre --fsname=LustreFS --mgs --mdt --backfstype=ldiskfs --reformat $mdt_device --index 0
	mkdir /mnt/mgsmds
	echo "$mdt_device /mnt/mgsmds lustre noatime,nodiratime,nobarrier 0 2" >> /etc/fstab
	mount -a

	# set up hsm
	lctl set_param -P mdt.*-MDT0000.hsm_control=enabled
	lctl set_param -P mdt.*-MDT0000.hsm.default_archive_id=1
	lctl set_param mdt.*-MDT0000.hsm.max_requests=128

	# allow any user and group ids to write
	lctl set_param mdt.*-MDT0000.identity_upcall=NONE

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

mkfs.lustre \
    --fsname=LustreFS \
    --backfstype=ldiskfs \
    --reformat \
    --ost \
    --mgsnode=$mds_ip \
    --index=$ost_index \
    $ost_device

mkdir /mnt/oss
echo "$ost_device /mnt/oss lustre noatime,nodiratime,nobarrier 0 2" >> /etc/fstab
mount -a


