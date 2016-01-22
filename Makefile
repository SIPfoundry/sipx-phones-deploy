PROJECTVER=2016.02-stage
DISTRO=x86_64
REPOHOST = stage.sipfoundry.org
REPOUSER = stage
PACKAGE = phones
WWWROOT = /var/stage/www-root
REPOPATH = ${WWWROOT}/sipxecs/${PROJECTVER}/${PACKAGE}/CentOS_6/${DISTRO}/
RPMPATH = RPMBUILD/RPMS/${DISTRO}/*.rpm
SSH_OPTIONS = -o UserKnownHostsFile=./.known_hosts -o StrictHostKeyChecking=no
SCP_PARAMS = ${RPMPATH} ${REPOUSER}@${REPOHOST}:${REPOPATH}
CREATEREPO_PARAMS = ${REPOUSER}@${REPOHOST} createrepo ${REPOPATH}
MKDIR_PARAMS = ${REPOUSER}@${REPOHOST} mkdir -p ${REPOPATH}
RM_PARAMS = ${REPOUSER}@${REPOHOST} rm -rf ${REPOPATH}/*
CONTAINER = sipfoundrydev/sipx-docker-config-libs:latest

MODULES = \
	sipXaudiocodes \
	sipXcounterpath \
	sipXgrandstream \
	sipXpolycom \
	sipXyealink

all: rpm

rpm-dir:
	@rm -rf RPMBUILD; \
	mkdir -p RPMBUILD/{DIST,BUILD,SOURCES,RPMS,SRPMS,SPECS};
	

configure: rpm-dir
	cd sipX${PACKAGE}; autoreconf -if
	cd RPMBUILD/DIST; ../../sipX${PACKAGE}/configure --prefix=`pwd`--enable-rpm

dist: configure
	cd RPMBUILD/DIST; \
	for mod in ${MODULES}; do \
		make $${mod}.dist; \
		if [[ $$? -ne 0 ]]; then \
			exit 1; \
		fi; \
	done

rpm: dist
	for mod in ${MODULES}; do \
		rpmbuild -ta --define "%_topdir `pwd`/RPMBUILD" RPMBUILD/DIST/$${mod}/$${mod,,}*.tar.gz; \
		if [[ $$? -ne 0 ]]; then \
			exit 1; \
		fi; \
		yum -y localinstall RPMBUILD/RPMS/${DISTRO}/$${mod,,}*.rpm; \
	done
		

deploy:
	ssh ${SSH_OPTIONS} ${MKDIR_PARAMS}; \
	if [[ $$? -ne 0 ]]; then \
		exit 1; \
	fi; \
	ssh ${SSH_OPTIONS} ${RM_PARAMS}; \
	scp ${SSH_OPTIONS} -r ${SCP_PARAMS}; \
	if [[ $$? -ne 0 ]]; then \
		exit 1; \
	fi; \
	ssh ${SSH_OPTIONS} ${CREATEREPO_PARAMS}; \
	if [[ $$? -ne 0 ]]; then \
		exit 1; \
	fi;

docker-build:
	docker pull ${CONTAINER}; \
	docker run -t --rm --name sipx-${PACKAGE}-builder  -v `pwd`:/BUILD ${CONTAINER} \
		/bin/sh -c "cd /BUILD && yum update -y && make";

prepare-repo:
	rm -f /etc/yum.repos.d/sipx*; \
	echo "[sipx-baselibs]" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "name=sipXecs custom packages for CentOS releasever - basearch" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "baseurl=file:///WWWROOT/sipxecs/2016.02-stage/externals/CentOS_6/x86_64" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "gpgcheck=0" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "[sipx-router]" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "name=sipXecs custom packages for CentOS releasever - basearch" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "baseurl=file:///WWWROOT/sipxecs/2016.02-stage/router/CentOS_6/x86_64" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "gpgcheck=0" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "[sipx-config]" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "name=sipXecs custom packages for CentOS releasever - basearch" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "baseurl=file:///WWWROOT/sipxecs/2016.02-stage/config/CentOS_6/x86_64" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "gpgcheck=0" >> /etc/yum.repos.d/sipxecs.repo; \
	echo "" >> /etc/yum.repos.d/sipxecs.repo;
                        
docker-build-local:
	docker pull ${CONTAINER}; \
	docker run -t  --rm --name sipx-${PACKAGE}-builder  -v `pwd`:/BUILD -v ${WWWROOT}:/WWWROOT ${CONTAINER} \
	/bin/sh -c "cd /BUILD && make prepare-repo && yum update -y && make"
