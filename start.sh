#!/bin/bash
set -e

# Options for starting Ganesha
: ${GANESHA_OPTIONS:="-N NIV_EVENT"} # NIV_DEBUG
: ${GANESHA_PROTOCOLS:="4"}
: ${GANESHA_TRANSPORTS:="UDP,TCP"}
: ${GANESHA_KRB5:="true"}
: ${GANESHA_SECTYPE:="krb5"}

function bootstrap_config {
	echo "Bootstrapping Ganesha NFS config"
  cat <<EOF > /usr/local/etc/ganesha/ganesha.conf
NFSv4 {
	Graceless = true;
}
NFS_KRB5 {
	Active_krb5 = ${GANESHA_KRB5};
}
EXPORT {
	# Export Id (mandatory, each EXPORT must have a unique Export_Id)
	Export_Id = 1;

	# Exported path (mandatory)
	Path = /export;

	# Pseudo Path (for NFS v4)
	Pseudo = /;

	# Access control options
	Access_Type = RW;
	Squash = No_Root_Squash;

	# NFS protocol options
	Transports = ${GANESHA_TRANSPORTS};
	Protocols = ${GANESHA_PROTOCOLS};

	SecType = ${GANESHA_SECTYPE};

	# Exporting FSAL
	FSAL {
		Name = VFS;
	}
}
EOF
}

function bootstrap_export {
	if [ ! -f ${GANESHA_EXPORT} ]; then
		mkdir -p "${GANESHA_EXPORT}"
  fi
}

function init_rpc {
	echo "Starting rpcbind"
	rpcbind || return 0
	rpc.statd -L || return 0
	rpc.idmapd || return 0
	sleep 1
}

function init_dbus {
	echo "Starting dbus"
	rm -f /var/run/dbus/system_bus_socket
	rm -f /var/run/dbus/pid
	dbus-uuidgen --ensure
	dbus-daemon --system --fork
	sleep 1
}

function startup_script {
	if [ -f "${STARTUP_SCRIPT}" ]; then
  	/bin/sh ${STARTUP_SCRIPT}
	fi
}

bootstrap_config
bootstrap_export
startup_script

init_rpc
init_dbus


echo "Starting Ganesha NFS"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
exec /usr/local/bin/ganesha.nfsd -F -L /dev/stdout ${GANESHA_OPTIONS}