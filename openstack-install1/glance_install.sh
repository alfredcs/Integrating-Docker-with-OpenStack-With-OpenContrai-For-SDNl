#!/bin/bash
set -x
function usage() {
cat <<EOF
usage: $0 options

This script will install Glance on this Openstack Controller

Example:
        glance_install.sh [-L] -v openstack_controller_vip [-r REPO_SERVERS]

OPTIONS:
  -h -- Help Show this message
  -L -- Use SSL
  -r -- Repo server names
  -V -- Verbose Verbose output
  -D -- Debug
  -v -- VIP of the openstack controller

EOF
}
first_openstack_controller=""
KEYSTONE_CMD=keystone
HTTP_CMD=http
[[ `id -u` -ne 0 ]] && { echo  "Must be root!"; exit 0; }
[[ $# -lt 1 ]] && { usage; exit 1; }
while getopts "hLr:v:VD" OPTION; do
case "$OPTION" in
h)
        usage
        exit 0
        ;;
L)
	KEYSTONE_CMD="keystone --insecure"
	HTTP_CMD=https
	;;
r)
	REPO_SERVERS="$OPTARG"
	;;
v)
        openstack_controller_vip="$OPTARG"
        ;;
V)
        display_version
        exit 0
        ;;
D)
        DEBUG=1
        ;;
\?)
        echo "Invalid option: -"$OPTARG"" >&2
        usage
        exit 1
        ;;
:)
        usage
        exit 1
        ;;
esac
done
local_host_name=`echo $HOSTNAME|cut -d. -f1`
local_controller=`egrep -w ${local_host_name} /etc/hosts|grep -v ^#|head -1| awk '{print $1}'`
if [[  ${local_controller} == ${local_controller}  ]]; then
	echo "Installing Glance on the firsth Openstack controller node ......"
else
	###
	# Get Keys
	###
	#[[ -f .keystone_grants ]] && { rm -rf .keystone_grants; rm -rf eystone_grants.enc; }
	#curl --insecure -o keystone_grants.enc https://${first_openstack_controller}/.tmp/keystone_grants.enc
	#[[  -f keystone/newkey.pem && -f keystone_grants.enc ]] && openssl rsautl -decrypt -inkey keystone/newkey.pem -in keystone_grants.enc -out .keystone_grants
	[[ ! -f  ./.keystone_grants ]] && { echo "Require credential file from Openstacl installation!"; exit 1; }
fi
GLANCE_KSPASS=${GLANCE_KSPASS:-`cat ./.keystone_grants|grep -i GLANCE_KSPASS| grep -v ^#|cut -d= -f2`}
GLANCE_DBPASS=${GLANCE_DBPASS:-`cat ./.keystone_grants|grep -i GLANCE_DBPASS| grep -v ^#|cut -d= -f2`}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-`cat ./.keystone_grants|grep -i MYSQL_ROOT_PASS| grep -v ^#|cut -d= -f2`}
#openstack_controller_vip=${openstack_controller_vip:-"cat ./.keystone_grants|grep -i openstack_controller| grep -v ^#|cut -d= -f2"}
domain_name=`echo $HOSTNAME|cut -d\. -f2,3,4,5`
domain_name=${domain_name:-"default.domain"}
[ `rpm -qa| egrep -Ei 'retrying|glance'|wc -l` -gt 0 ] && rpm -e --nodeps `rpm -qa|egrep -Ei 'glance|retrying|swiftclient|cinderclient'`
[ `rpm -qa| grep rabbitmq-server|wc -l` -gt 0 ] && rpm -e --nodeps `rpm -qa|egrep 'rabbitmq-server'`
[ `rpm -qa| grep erlang|wc -l` -lt 1 ] && yum -y install erlang
[ `rpm -qa| grep openstack-glance|wc -l` -lt 1 ] && yum -y install  --disablerepo=* --enablerepo=${REPO_SERVERS} glance python-glanceclient \
	retrying WSME ipaddr simplegeneric osprofiler enum34 httplib2 oslo.vmware \
	utils suds python-cinderclient glance_store python-swiftclient rabbitmq-server keystonemiddleware pycrypto

[[ $? -ne 0 ]] && exit 1
#####
# Setup glance
#####
useradd -M glance; usermod -L glance
[[ ! -d /etc/glance ]] && { mkdir -p /etc/glance; chown -R glance:glance /etc/glance; }
[[ ! -d /var/log/glance ]] && { mkdir -p /var/log/glance; chown -R glance:glance /var/log/glance; }
chown -R glance:glance /etc/glance
[[ -f ~/contrc ]] && source ~/contrc
[[ -f ./glance/openstack-glance-api.service ]] && /bin/cp -f ./glance/openstack-glance-api.service /lib/systemd/system/openstack-glance-api.service
[[ -f ./glance/openstack-glance-registry.service ]] && /bin/cp -f ./glance/openstack-glance-registry.service /lib/systemd/system/openstack-glance-registry.service
[[ -f /lib/systemd/system/openstack-glance-api.service ]] && ln -s /lib/systemd/system/openstack-glance-api.service /etc/systemd/system/openstack-glance-api.service
[[ -f /lib/systemd/system/openstack-glance-registry.service ]] && ln -s /lib/systemd/system/openstack-glance-registry.service /etc/systemd/system/openstack-glance-registry.service
systemctl stop openstack-glance-api.service
systemctl stop openstack-glance-registry.service

###
# Config Glance
####
for file_n in schema-image.json policy.json glance-scrubber.conf glance-cache.conf glance-registry-paste.ini glance-api-paste.ini 
do
	[[ -f ./glance/${file_n} ]] && /bin/cp -p ./glance/${file_n} /etc/glance/${file_n}
done
[[ -f ./glance/glance-api.conf.controller ]] && /bin/cp -f ./glance/glance-api.conf.controller /etc/glance/glance-api.conf
[[ -f ./glance/glance-registry.conf.controller ]] && /bin/cp -f ./glance/glance-registry.conf.controller /etc/glance/glance-registry.conf
sed -i "s/GLANCE_DBPASS/${GLANCE_DBPASS}/g" /etc/glance/glance-api.conf
sed -i "s/GLANCE_DBPASS/${GLANCE_DBPASS}/g" /etc/glance/glance-registry.conf
sed -i "s/GLANCE_KSPASS/${GLANCE_KSPASS}/g" /etc/glance/glance-api.conf
sed -i "s/GLANCE_KSPASS/${GLANCE_KSPASS}/g" /etc/glance/glance-registry.conf
sed -i "s/GLANCE_KSPASS/${GLANCE_KSPASS}/g" /etc/glance/glance-api-paste.ini
sed -i "s/openstack_controller_vip/${openstack_controller_vip}/g" /etc/glance/glance-api.conf
sed -i "s/openstack_controller_vip/${openstack_controller_vip}/g" /etc/glance/glance-registry.conf
sed -i "s/openstack_controller_vip/${openstack_controller_vip}/g" /etc/glance/glance-api-paste.ini
sed -i "s/HTTP_CMD/${HTTP_CMD}/g" /etc/glance/glance-api.conf
sed -i "s/HTTP_CMD/${HTTP_CMD}/g" /etc/glance/glance-registry.conf
chown -R glance:glance etc/glance;chown -R glance:glance /var/run/glance;chown -R glance:glance /var/lib/glance;chown -R glance:glance /var/log/glance

#####
# Creat glance in Keystone if needed
#####
if [ `${KEYSTONE_CMD} user-list| grep glance | wc -l` -lt 1 ]; then
        ${KEYSTONE_CMD} user-create --name=glance --pass=$GLANCE_KSPASS --email=glance@$domain_name
        ${KEYSTONE_CMD} user-role-add --user=glance --tenant=service --role=admin
fi

###
# Swiftcleint temp fix
###
[[ -f /usr/lib/python2.7/site-packages/glance_store/_drivers/swift/store.py ]] && sed -i "/swiftclient/ s/^import/#import/" /usr/lib/python2.7/site-packages/glance_store/_drivers/swift/store.py
####
# Glance Mysql DB init
####
if [[ ${local_controller} == ${local_controller}  ]]; then
	#/usr/bin/openstack-db --drop --yes --rootpw ${MYSQL_ROOT_PASS}  --service glance
	[[ ! -z `mysql -uroot -p${MYSQL_ROOT_PASS} -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='glance'"` ]] &&  mysql -uroot -p${MYSQL_ROOT_PASS} -qfsBe "drop database glance"
	#openstack-db --init --service glance --password $GLANCE_DBPASS
	echo "create database glance;" > /tmp/._glance.sql
	echo "grant all on glance.* to glance@'%' identified by '$GLANCE_DBPASS';" >> /tmp/._glance.sql
	echo "grant all on glance.* to glance@'localhost' identified by '$GLANCE_DBPASS';" >> /tmp/._glance.sql
	echo "grant all on glance.* to glance@'${local_controller}' identified by '$GLANCE_DBPASS';" >> /tmp/._glance.sql
	mysql -uroot -p${MYSQL_ROOT_PASS} < /tmp/._glance.sql
	chown -R glance:glance /var/log/glance;chown -R glance:glance /var/lib/glance
	#[[ `pip freeze| grep pycryto | wc -l` -lt 1  && -f ../sdn-install1/fixes/pycrypto-2.6.tar.gz ]] &&  pip-python install ../sdn-install1/fixes/pycrypto-2.6.tar.gz
	/bin/sh -c "glance-manage db_sync" glance
	#glance-manage db_sync
	[[ $? -ne 0 ]] && { echo "Glance DB init failed"; exit 1; }
	#[ -f ~/glance/glance.sql ] && mysql -u root -p < ~/glance/glance.sql
fi

####
# Create Glance service in Keystone
####

[ `${KEYSTONE_CMD} service-list | grep glance | wc -l` -lt 1 ] && ${KEYSTONE_CMD} service-create --name=glance --type=image --description="Glance Image Service" 
GLANCE_SERVICE_ID=`${KEYSTONE_CMD} service-list | grep -i glance|awk '{print $2}'`
[ `${KEYSTONE_CMD} endpoint-list | grep $GLANCE_SERVICE_ID | wc -l ` -lt 1 ] && ${KEYSTONE_CMD} endpoint-create --service-id=`${KEYSTONE_CMD} service-list|grep glance|awk '{print $2}'` --publicurl=${HTTP_CMD}://${openstack_controller_vip}:9292/v1 --internalurl=${HTTP_CMD}://${openstack_controller_vip}:9292/v1 --adminurl=${HTTP_CMD}://${openstack_controller_vip}:9292/v1 

##
# Rabbit MQ
##
if [[ -f rabbitmq/rabbitmq.config.controller ]]; then
        /bin/cp -f rabbitmq/rabbitmq.config.controller /etc/rabbitmq/rabbitmq.config
	first_openstack_controller_host=`fgrep ${local_controller} /etc/hosts| grep -v ^#| awk '{print $2}'|cut -d\. -f1|head -1`
	#second_openstack_controller_host=`fgrep ${second_openstack_controller} /etc/hosts| grep -v ^#| awk '{print $2}'|cut -d\. -f1|head -1`
	#third_openstack_controller_host=`fgrep ${third_openstack_controller} /etc/hosts| grep -v ^#| awk '{print $2}'|cut -d\. -f1|head -1`
        sed -i "s/first_openstack_controller/${first_openstack_controller_host}/" /etc/rabbitmq/rabbitmq.config
        #sed -i "s/second_openstack_controller/${second_openstack_controller_host}/" /etc/rabbitmq/rabbitmq.config
        #sed -i "s/third_openstack_controller/${third_openstack_controller_host}/" /etc/rabbitmq/rabbitmq.config
fi

[[ -f rabbitmq/.erlang.cookie ]] && { /bin/cp -p rabbitmq/.erlang.cookie /var/lib/rabbitmq/.erlang.cookie; chmod 0400 /var/lib/rabbitmq/.erlang.cookie; chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie; }
service rabbitmq-server stop
[[ `ps -ef | grep rabbitmq|wc -l` -gt 0 ]] && kill -9 `ps -ef | grep rabbit| grep -v grep| awk '{print $2}'`
/usr/sbin/rabbitmq-server --detached &
sleep 2
/usr/sbin/rabbitmqctl stop_app
[[ ! ${local_openstack_controller} == ${local_controller} ]] && /usr/sbin/rabbitmqctl join_cluster rabbit@`fgrep ${local_controller} /etc/hosts| grep -v ^#| awk '{print $2}'|cut -d\. -f1|head -1`
/usr/sbin/rabbitmqctl start_app
#[[ ${local_controller} == ${local_controller} ]] &&  /usr/sbin/rabbitmqctl set_policy cluster-all-queues '^(?!amq\.).*' '{"ha-mode":"all","ha-sync-mode":"automatic"}'

###
# SSL fix for dashboard by Sanju
###
[[ -f ./glance/http.py ]] && /bin/cp -p ./glance/http.py /usr/lib/python2.6/site-packages/glanceclient/common
[[ -f ./glance/images.py ]] && /bin/cp -p ./glance/images.py /usr/lib/python2.6/site-packages/glance/api/v2
[[ -f ./glance/__init__.py ]] && /bin/cp -p ./glance/__init__.py /usr/lib/python2.6/site-packages/glance/domain

####
# Permisstion
#####
for file_p in /var/lib/glance/images /var/lib/glance/scrubber /var/lib/glance/image-cache /etc/glance
do
	[[ ! -d ${file_p} ]] && mkdir -p ${file_p}
	[[ -d ${file_p} ]] && chown -R glance:glance ${file_p}
done
####
# Restart
####
systemctl enable openstack-glance-api.service 
systemctl enable openstack-glance-registry.service 
systemctl restart openstack-glance-api.service
systemctl restart openstack-glance-registry.service
