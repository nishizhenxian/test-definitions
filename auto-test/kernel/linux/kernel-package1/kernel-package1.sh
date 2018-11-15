#!/bin/bash
# Copyright (C) 2018-8-29, Estuary
# Author: wangsisi

# Test user id
if [ `whoami` != 'root' ] ; then
    echo "You must be the superuser to run this script" >&2
    exit 1
fi

cd ../../../../utils
source        ./sys_info.sh
source         ./sh-test-lib
cd -

###################  Environmental preparation  #######################

######################  testing the step #############################
case "${distro}" in
    debian)
		source_version_remove(){    
			p=$1
			s=$(apt show $p | grep "Source" | awk '{print $2}')	             
			v=$(apt show $p | grep "Version" | awk '{print $2}')		              
			if [ "$s" = "${source1}" -o "$s" = "${source2}" ];then				                 
			   print_info 0 ${p}_source
			else
			   print_info 1 ${p}_source
			fi

			if [ "$v" = "${iversion}" -o "$v" = "${version2}" -o "$v" = "${version3}" ];then
				print_info 0 ${p}_version
			else
				print_info 1 ${p}_version
			fi

			uname=$(uname -r)
			if [ "$p" = "linux-image-${uname}" ];then
			echo -e "$blue this package isn't remove$NC"
			else
			   apt remove -y $p
			   print_info $? ${p}_remove
			fi
		}
		sed -i s/5.[0-9]/5.2/g /etc/apt/sources.list.d/estuary.list
		apt-get update
		apt-get install -y libcpupower-dev linux-estuary-doc usbip > /dev/null
		iversion=$(apt show libcpupower-dev| grep "Version" | awk '{print $2}')
		version2=$(apt show linux-estuary-doc| grep "Version" | awk '{print $2}')
		version3=$(apt show usbip| grep "Version" | awk '{print $2}')
		source1=$(apt show libcpupower-dev| grep "Source"|awk '{print $2}')
		source2=$(apt show linux-estuary-doc| grep "Source"|awk '{print $2}')
		apt-get remove -y libcpupower-dev linux-estuary-doc usbip > /dev/null
		package_list="libcpupower1 libcpupower-dev linux-cpupower linux-estuary-doc linux-estuary-perf linux-estuary-source linux-headers linux-headers-estuary-arm64 linux-image linux-image-estuary-arm64 linux-kbuild linux-libc-dev linux-perf linux-source linux-support usbip "
		for p in ${package_list};do
			echo "$p install................."
			apt-get install -y $p
			vs=$(apt show $p | grep "Version" | awk '{print $2}')
			status=$?
			if [ "$vs" != "$iversion" -o "$vs" != "$version2" -o "$vs" != "$version3" ];then
			   status=1 
			fi
			if [ $status -eq 0 ];then
				print_info 0 ${p}_install
				source_version_remove $p
			else
				pa=$(apt search $p | grep $iversion | grep -v db | grep $p |cut -d "/" -f 1)
				pa_num=$(apt search $p | grep $iversion | grep -v db | grep $p |cut -d "/" -f 1|wc -l)
				if [ $pa_num = 1 ]; then
					apt-get install -y $pa
				print_info 0 ${pa}_install
				source_version_remove $pa
				else
					for i in $pa ;do
						apt-get install -y $i
					print_info 0 ${i}_install
				source_version_remove $i
					done
				fi
			fi
		done
    centos)
        sed -i s/5.[0-9]/5.2/g /etc/yum.repos.d/estuary.repo
        yum clean all
	yum install -y kernel-tools-libs-devel >/dev/null
        version=$(yum info kernel-tools-libs-devel | grep -i "version" | awk '{print $3}')
        release=$(yum info kernel-tools-libs-devel | grep -i "release" | awk '{print $3}')
        from_repo=$(yum info kernel-tools-libs-devel | grep -i "from repo" | awk '{print $4}')
        yum remove -y kernel-tools-libs-devel > /dev/null
	#version="4.16.0"
        #release="estuary.6"
        #from_repo="Estuary"
        package_list="kernel-devel kernel-headers kernel-tools-libs kernel-tools-libs-devel perf python-perf  kernel-debug kernel-debug-debuginfo"
        for p in ${package_list};do
            echo "$p install"
            yum install -y $p
            status=$?
            rmflag=0
            if test $status -eq 0
            then
                 print_info 0 install
                from=$(yum info $p | grep "From repo" | awk '{print $4}')
                if [ "$from" = "$from_repo" ];then
                   print_info 0 repo_check
                else
                    #已经安装，但是安装源不是estuary的情况需要卸载重新安装
                    rmflag=1
                    if [ "$from" != "Estuary" ];then
                        yum remove -y $p
                        yum install -y $p
                        from=$(yum info $p | grep "From repo" | awk '{print $4}')
                        if [ "$from" = "$from_repo" ];then
                             print_info 0 repo_check
                        else
                            print_info 1 repo_check
                        fi
                    fi
                fi

                vs=$(yum info $p | grep "Version" | awk '{print $3}')
                if [ "$vs" = "$version" ];then
                      print_info 0 version
                else
                      print_info 1 version
                fi

                rs=$(yum info $p | grep "Release" | awk '{print $3}')
                if [ "$rs" = "$release" ];then
                     print_info 0 release
                else
                     print_info 1 release
                fi
                #对于自带的包不去做卸载处理
                if test $rmflag -eq 0
                then
                    yum remove -y $p
                    status=$?
                    if test $status -eq 0
                    then
                        print_info 0 remove
                    else
                        print_info 1 remove
                    fi
                else
                    echo "$p don't remove" | tee -a ${RESULT_FILE}
                fi
            else
                echo "$p install [FAIL]"  | tee -a ${RESULT_FILE}
            fi
        done
        ;;
    ubuntu)
        sed -i s/5.[0-9]/5.1/g /etc/apt/sources.list.d/estuary.list 
        apt-get update -q=2
        v='4.16.0-504'
        v1='4.16.0'
        package_list="linux-estuary linux-headers-estuary linux-source-estuary linux-tools-estuary linux-cloud-tools-common linux-doc linux-headers-${v} linux-headers-${v}-generic linux-image-${v}-generic linux-image-extra-${v}-generic linux-source-${v1} linux-tools-${v} linux-tools-${v}-generic linux-tools-common"
        for p in ${package_list};do
            echo "$p install"
            apt-get install -y $p
            status=$?
            from_repo1='linux-meta-estuary'
            from_repo2='linux'
            version1='4.16.0.504.2'
            version2='4.16.0-504.estuary'
            rmflag=0
            if test $status -eq 0
            then
                print_info 0 installa
                from=$(apt show $p | grep -i "Source" | awk '{print $2}')
                if [ "$from" = "$from_repo1" -o "$from" = "$from_repo2" ];then
                    print_info 0 repo_check
                else
                    rmflag=1
                    apt-get remove -y $p
                    apt-get install -y $p
                    from=$(apt show $p | grep "Source" | awk '{print $2}')
                    if [ "$from" = "$from_repo1" -o "$from" = "$from_repo2" ];then
                       print_info 0 repo_check
                    else
                       print_info 1 repo_check
                    fi
                fi

                vs=$(apt show $p | grep "Version" | awk '{print $2}')
                if [ "$vs" = "$version1" -o "$vs" = "$version2" ];then
                    print_info 0 version_check 
                else
                    print_info 1 version_check 
                fi
            fi
            if [ "$p" != "linux-image-${v}-generic" ];then  
                echo "$p remove"
                apt-get remove -y $p
                status=$?
                if test $status -eq 0
                then
                    print_info 0 remove
                else
                    print_info 1 remove
                fi
            fi
        done
        ;;
    fedora)
        sed -i s/5.[0-9]/5.1/g /etc/yum.repos.d/estuary.repo
        yum update
        version="4.16.0"
        release="estuary.2.fc26"
        from_repo="estuary"
        from_repo1="Estuary"
        package_list="kernel kernel-core kernel-devel kernel-headers kernel-debuginfo kernel-debuginfo-common kernel-modules kernel-modules-extra"
        for p in ${package_list};do
            echo "$p install"
            yum install -y $p
            status=$?
            rmflag=0
            if test $status -eq 0
            then
                 print_info 0 install
                from=$(yum info $p | grep "From repo" | awk '{print $4}'|head -1)
                if [ "$from" = "$from_repo" -o "$from" = "$from_repo1" ];then
                   print_info 0 repo_check
                else
                    #已经安装，但是安装源不是estuary的情况需要卸载重新安装
                    rmflag=1
                    if [ "$from" != "$from_repo"  -o "$from" != "$from_repo1" ];then
                        yum remove -y $p
                        yum install -y $p
                        from=$(yum info $p | grep "From repo" | awk '{print $4}'|head -1)
                        if [ "$from" = "$from_repo" -o "$from" = "$from_repo1" ];then
                             print_info 0 repo_check
                        else
                            print_info 1 repo_check
                        fi
                    fi
                fi

                vs=$(yum info $p | grep "Version      : 4.16.0" | awk '{print $3}'|head -1)
                if [ "$vs" = "$version" ];then
                      print_info 0 version
                else
                      print_info 1 version
                fi

                rs=$(yum info $p | grep "Release      : estuary.2.fc26" | awk '{print $3}'|head -1)
                if [ "$rs" = "$release" ];then
                     print_info 0 release
                else
                     print_info 1 release
                fi
                #对于自带的包不去做卸载处理
                if test $rmflag -eq 0
                then
                    yum remove -y $p
                    status=$?
                    if test $status -eq 0
                    then
                        print_info 0 remove
                    else
                        print_info 1 remove
                    fi
                else
                    echo "$p don't remove" | tee -a ${RESULT_FILE}
                fi
            else
                echo "$p install [FAIL]"  | tee -a ${RESULT_FILE}
            fi
        done
        ;;
    opensuse)
         version="4.16.3-0.gd41301c" 
         source1="kernel-default-4.16.3-0.gd41301c.nosrc"  
         installed="No"
         package_list="kernel-default kernel-default-base"
          wget ftp://117.78.41.188/utils/distro-binary/opensuse/kernel-default-4.16.3-0.gd41301c.aarch64.rpm
         wget ftp://117.78.41.188/utils/distro-binary/opensuse/kernel-default-base-4.16.3-0.gd41301c.aarch64.rpm
#         wget ftp://117.78.41.188/utils/distro-binary/opensuse/kernel-default-devel-4.16.3-0.gd41301c.aarch64.rpm         
          for p in ${package_list};do  
               inst=$(zypper info $p  |grep  "Installed      :" | awk '{print $3}')  
               if [ "$p" = "kernel-default" ];then
                  if [ "$inst" = "$installed" ];then
                     zypper --no-gpg-checks install -y kernel-default-4.16.3-0.gd41301c.aarch64.rpm
                     print_info $? install
                  else
                     zypper remove -y $p
                     zypper --no-gpg-checks install -y kernel-default-4.16.3-0.gd41301c.aarch64.rpm
                     print_info $? install
                  fi
               fi

               if [ "$p" = "kernel-default-base" ];then
                  if [ "$inst" = "$installed" ];then
                     zypper --no-gpg-checks install -y kernel-default-base-4.16.3-0.gd41301c.aarch64.rpm
                     print_info $? install
                  else
                     zypper remove -y $p
                     zypper --no-gpg-checks install -y kernel-default-base-4.16.3-0.gd41301c.aarch64.rpm
                     print_info $? install 
                  fi
               fi

#               if [ "$p" = "kernel-default-devel" ];then
#                  if [ "$inst" = "$installed" ];then
#                    zypper --no-gpg-checks  install -y kernel-default-devel-4.16.3-0.gd41301c.aarch64.rpm
#                    print_info $? install
#                 else
#                     zypper remove -y $p
#                     zypper --no-gpg-checks install -y kernel-default-devel-4.16.3-0.gd41301c.aarch64.rpm
#                     print_info $? install
#                  fi                   
#               fi
               vs=$(zypper info $p | grep "Version" | awk '{print $3}')               
                  if [ "$vs" = "$version" ];then
                      print_info 0 version
                  else
                      print_info 1 version
                  fi
              sr=$(zypper info $p | grep "Source package" | awk '{print $4}')
                  if [ "$sr" = "$source1" ];then
                      print_info 0 source_package
                  else
                      print_info 1 source_package
                  fi
              zypper remove -y $p
              print_info $? remove
         done
         ;;   
esac
######################  environment  restore ##########################
