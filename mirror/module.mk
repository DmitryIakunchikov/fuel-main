/:=$(LOCAL_MIRROR)/

$/%: /:=$/

METADATA_FILES:=repomd.xml comps.xml filelists.xml.gz primary.xml.gz other.xml.gz

CENTOSEXTRA_PACKAGES:=$(shell grep -v ^\\s*\# requirements-rpm.txt)
CENTOSRPMFORGE_PACKAGES:=qemu

# RPM PACKAGE CACHE RULES

ifeq ($(IGNORE_MIRROR),1)
REPO_SUFFIX=real
else
REPO_SUFFIX=mirror
endif

define yum_conf
[main]
cachedir=$(CENTOS_REPO_DIR)cache
keepcache=0
debuglevel=6
logfile=$(CENTOS_REPO_DIR)yum.log
exactarch=1
obsoletes=1
gpgcheck=0
plugins=0
reposdir=$(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).repos.d
endef

$(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).conf: export contents:=$(yum_conf)
$(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).conf:
	@mkdir -p $(@D)
	echo "$${contents}" > $@

define yum_mirror_repo
[mirror]
name=CentOS $(CENTOS_RELEASE) - Base
baseurl=$(REPOMIRROR)/Packages
gpgcheck=0
enabled=1
endef

define yum_real_repo
[base]
name=CentOS-$(CENTOS_RELEASE) - Base
#mirrorlist=http://mirrorlist.centos.org/?release=$(CENTOS_RELEASE)&arch=$(CENTOS_ARCH)&repo=os
baseurl=$(CENTOSMIRROR)/$(CENTOS_RELEASE)/os/$(CENTOS_ARCH)
gpgcheck=0
enabled=1

[updates]
name=CentOS-$(CENTOS_RELEASE) - Updates
#mirrorlist=http://mirrorlist.centos.org/?release=$(CENTOS_RELEASE)&arch=$(CENTOS_ARCH)&repo=updates
baseurl=$(CENTOSMIRROR)/$(CENTOS_RELEASE)/updates/$(CENTOS_ARCH)
gpgcheck=0
enabled=1

[extras]
name=CentOS-$(CENTOS_RELEASE) - Extras
#mirrorlist=http://mirrorlist.centos.org/?release=$(CENTOS_RELEASE)&arch=$(CENTOS_ARCH)&repo=extras
baseurl=$(CENTOSMIRROR)/$(CENTOS_RELEASE)/extras/$(CENTOS_ARCH)
gpgcheck=0
enabled=1

[centosplus]
name=CentOS-$(CENTOS_RELEASE) - Plus
#mirrorlist=http://mirrorlist.centos.org/?release=$(CENTOS_RELEASE)&arch=$(CENTOS_ARCH)&repo=centosplus
baseurl=$(CENTOSMIRROR)/$(CENTOS_RELEASE)/centosplus/$(CENTOS_ARCH)
gpgcheck=0
enabled=1

[contrib]
name=CentOS-$(CENTOS_RELEASE) - Contrib
#mirrorlist=http://mirrorlist.centos.org/?release=$(CENTOS_RELEASE)&arch=$(CENTOS_ARCH)&repo=contrib
baseurl=$(CENTOSMIRROR)/$(CENTOS_RELEASE)/contrib/$(CENTOS_ARCH)
gpgcheck=0
enabled=1

[epel]
name=Extra Packages for Enterprise Linux $(CENTOS_MAJOR) - $(CENTOS_ARCH)
#mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-$(CENTOS_MAJOR)&arch=$(CENTOS_ARCH)
baseurl=$(EPELMIRROR)/$(CENTOS_MAJOR)/$(CENTOS_ARCH)
gpgcheck=0
enabled=1

[mirantis]
name=Mirantis Packages for CentOS
baseurl=http://moc-ci.srt.mirantis.net/rpm
gpgcheck=0
enabled=0

[rpmforge]
name=RHEL $(CENTOS_RELEASE) - RPMforge.net - dag
#mirrorlist = http://apt.sw.be/redhat/el$(CENTOS_MAJOR)/en/mirrors-rpmforge
baseurl=$(RPMFORGEMIRROR)/el$(CENTOS_MAJOR)/en/$(CENTOS_ARCH)/rpmforge
gpgcheck=0
enabled=0

[rpmforge-extras]
name = RHEL $(CENTOS_RELEASE) - RPMforge.net - extras
#mirrorlist = http://apt.sw.be/redhat/el$(CENTOS_MAJOR)/en/mirrors-rpmforge-extras
baseurl = $(RPMFORGEMIRROR)/el$(CENTOS_MAJOR)/en/$(CENTOS_ARCH)/extras
gpgcheck = 0
enabled = 0

[puppetlabs]
name=Puppet Labs Packages
baseurl=http://yum.puppetlabs.com/el/$(CENTOS_MAJOR)/products/$(CENTOS_ARCH)/
enabled=1
gpgcheck=1
gpgkey=http://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs
endef

$(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).repos.d/base.repo: export contents:=$(yum_$(REPO_SUFFIX)_repo)

$(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).repos.d/base.repo:
	@mkdir -p $(@D)
	echo "$${contents}" > $@

$(CENTOS_REPO_DIR)repodata/comps.xml.gz:
	@mkdir -p $(@D)
	wget -O $@ $(CENTOS_MIRROR)/`wget -qO- $(CENTOS_MIRROR)/repodata/repomd.xml | \
	 xml2 | grep 'comps\.xml\.gz' | awk -F'=' '{ print $$2 }'`

$(CENTOS_REPO_DIR)repodata/comps.xml: $(CENTOS_REPO_DIR)repodata/comps.xml.gz
	gunzip -c $(CENTOS_REPO_DIR)repodata/comps.xml.gz > $@

$/cache-boot.done: \
	    $(addprefix $(CENTOS_REPO_DIR)/images/,$(IMAGES_FILES)) \
	    $(addprefix $(CENTOS_REPO_DIR)/EFI/BOOT/,$(EFI_FILES)) \
	    $(addprefix $(CENTOS_REPO_DIR)/isolinux/,$(ISOLINUX_FILES))
	$(ACTION.TOUCH)

$/cache-infra.done: \
	  $(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).conf \
	  $(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).repos.d/base.repo
	$(ACTION.TOUCH)

$/cache-extra.done: \
		$(CENTOS_REPO_DIR)repodata/comps.xml \
	 	$/cache-infra.done
	CENTOSMIN_PACKAGES=$(shell grep "<packagereq type='mandatory'>" $(CENTOS_REPO_DIR)comps.xml | sed -e "s/^\s*<packagereq type='mandatory'>\(.*\)<\/packagereq>\s*$$/\\1/")
	yum -c $(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).conf clean all
	rm -rf /var/tmp/yum-$$USER-*/
ifeq ($(IGNORE_MIRROR),1)
	repotrack -c $(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).conf -p $(CENTOS_REPO_DIR)Packages -a $(CENTOS_ARCH) $(CENTOSMIN_PACKAGES) $(CENTOSEXTRA_PACKAGES)
	repotrack -r base -r updates -r extras -r contrib -r centosplus -r epel -r rpmforge-extras -c $(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).conf -p $(CENTOS_REPO_DIR)Packages -a $(CENTOS_ARCH) $(CENTOSRPMFORGE_PACKAGES)
else
	repotrack -c $(CENTOS_REPO_DIR)etc/yum-$(REPO_SUFFIX).conf -p $(CENTOS_REPO_DIR)Packages -a $(CENTOS_ARCH) $(CENTOSMIN_PACKAGES) $(CENTOSEXTRA_PACKAGES) $(CENTOSRPMFORGE_PACKAGES)
endif
	$(ACTION.TOUCH)

$/cache.done: $/cache-extra.done $/eggs-gems.done $/cache-boot.done
	$(ACTION.TOUCH)

$(addprefix $(CENTOS_REPO_DIR)Packages/repodata/,$(METADATA_FILES)): $/cache.done $(CENTOS_REPO_DIR)repodata/comps.xml
	createrepo -g `readlink -f "$(CENTOS_REPO_DIR)repodata/comps.xml"` -o $(CENTOS_REPO_DIR)Packages $(CENTOS_REPO_DIR)Packages

$/repo.done: $(addprefix $(CENTOS_REPO_DIR)Packages/repodata/,$(METADATA_FILES))
	touch $@

# centos isolinux files

$(addprefix $(CENTOS_REPO_DIR)/isolinux/,$(ISOLINUX_FILES)):
	@mkdir -p $(@D)
	wget -O $@ $(CENTOS_MIRROR)/isolinux/$(@F)

# centos EFI boot images

$(addprefix $(CENTOS_REPO_DIR)/EFI/BOOT/,$(EFI_FILES)):
	@mkdir -p $(@D)
	wget -O $@ $(CENTOS_MIRROR)/EFI/BOOT/$(@F)

# centos boot images

$(addprefix $(CENTOS_REPO_DIR)/images/,$(IMAGES_FILES)):
	@mkdir -p $(@D)
	wget -O $@ $(CENTOS_MIRROR)/images/$(@F)

# centos netinstall iso

$(CENTOS_ISO_DIR)/$(NETINSTALL_ISO):
	mkdir -p $(@D)
	wget -O $@ $(CENTOS_NETINSTALL)/$(NETINSTALL_ISO)

# EGGS AND GEMS

$/eggs-gems.done: requirements-gems.txt requirements-eggs.txt
	@mkdir -p $/eggs
	@mkdir -p $/gems
	@awk -v mirror=$/eggs '{system ("[ `find " mirror " -name " $$1 "-"$$2 "* ` ] || pip install -d " mirror " " $$1 "=="$$2 )}' ./requirements-eggs.txt
	@awk -v mirror=$/gems '{system ("[ `find " mirror " -name " $$1 "-"$$2 "*` ] || ( cd "mirror" && gem fetch "$$1" -v "$$2")")}' ./requirements-gems.txt
	$(ACTION.TOUCH)

mirror: $(addprefix $(CENTOS_REPO_DIR)Packages/repodata/,$(METADATA_FILES)) \
	$(CENTOS_ISO_DIR)/$(NETINSTALL_ISO) \
	$/cache-boot.done \
	$/eggs-gems.done
