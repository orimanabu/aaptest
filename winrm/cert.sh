#!/bin/bash

# ./certs.sh 1 myca
# ./certs.sh 2 myca myingress

if [ x"$#" == x"0" ]; then
	echo "$0 step ..."
	exit 1
fi
step=$1; shift

TEST=echo
outdir=./pki
mkdir -p ${outdir}

#keysize=2048
keysize=4096
period=3650
country_name=JP
state_name=Tokyo
locality_name=Shibuya-ku
email=mori@redhat.com
org_name=MYCOMPANY
org_unit_name=HQ

case ${step} in
1|ca|CA)
	if [ x"$#" != x"1" ]; then
		echo "$0 step ca_name"
		exit 1
	fi
	arg=$1; shift

	common_name=myauthority
	#subject="/C=${country_name}/ST=${state_name}/L=${locality_name}/O=${org_name}/OU=${org_unit_name}/CN=${common_name}/emailAddress=${email}"
	subject="/O=${org_name}/OU=${org_unit_name}/CN=${common_name}"

	echo "=> CA"
	echo "==> Private Key"
	${TEST} openssl genrsa -out ${outdir}/${arg}.key ${keysize}
	echo "==> CSR"
	${TEST} openssl req -new -key ${outdir}/${arg}.key -out ${outdir}/${arg}.csr -sha256 -subj ${subject}
	echo "==> Certificate"
	${TEST} openssl x509 -req -days ${period} -signkey ${outdir}/${arg}.key -in ${outdir}/${arg}.csr -out ${outdir}/${arg}.crt -extensions v3_ca -extfile openssl.conf
	echo "==> Confirm"
	${TEST} openssl x509 -in ${outdir}/${arg}.crt -text | grep -E '(Issuer|Subject):'
	echo "==> PFX"
	${TEST} openssl pkcs12 -export -password pass: -out ${outdir}/${arg}.pfx -inkey ${outdir}/${arg}.key -in ${outdir}/${arg}.crt
	;;
2|server|Server)
	if [ x"$#" != x"2" ]; then
		echo "$0 step ca_name server_name"
		exit 1
	fi
	ca_name=$1; shift
	arg=$1; shift

	common_name=wintest1
	#subject="/C=${country_name}/ST=${state_name}/L=${locality_name}/O=${org_name}/OU=${org_unit_name}/CN=${common_name}/emailAddress=${email}"
	subject="/O=${org_name}/OU=${org_unit_name}/CN=${common_name}"

	echo "=> Server"
	echo "==> Private Key"
	${TEST} openssl genrsa -out ${outdir}/${arg}.key ${keysize}
	echo "==> CSR"
	${TEST} openssl req -new -key ${outdir}/${arg}.key -out ${outdir}/${arg}.csr -sha256 -subj ${subject}
	echo "==> Certificate"
	${TEST} openssl x509 -req -days ${period} -CA ${outdir}/${ca_name}.crt -CAkey ${outdir}/${ca_name}.key -CAcreateserial -in ${outdir}/${arg}.csr -out ${outdir}/${arg}.crt -extensions v3_server -extfile openssl.conf
	echo "==> Confirm"
	${TEST} openssl x509 -in ${outdir}/${arg}.crt -text | grep -E '(Issuer|Subject):'
	echo "==> PFX"
	${TEST} openssl pkcs12 -export -password pass: -out ${outdir}/${arg}.pfx -inkey ${outdir}/${arg}.key -in ${outdir}/${arg}.crt
	;;
0|selfserver)
	if [ x"$#" != x"1" ]; then
		echo "$0 step server_name"
		exit 1
	fi
	arg=$1; shift

	common_name=wintest1
	#subject="/C=${country_name}/ST=${state_name}/L=${locality_name}/O=${org_name}/OU=${org_unit_name}/CN=${common_name}/emailAddress=${email}"
	subject="/O=${org_name}/OU=${org_unit_name}/CN=${common_name}"

	echo "=> Server"
	echo "==> Private Key"
	${TEST} openssl genrsa -out ${outdir}/${arg}.key ${keysize}
	echo "==> CSR"
	${TEST} openssl req -new -key ${outdir}/${arg}.key -out ${outdir}/${arg}.csr -sha256 -subj ${subject}
	echo "==> Certificate"
	${TEST} openssl x509 -req -days ${period} -signkey ${outdir}/${arg}.key -in ${outdir}/${arg}.csr -out ${outdir}/${arg}.crt -extensions v3_server -extfile openssl.conf
	echo "==> Confirm"
	${TEST} openssl x509 -in ${outdir}/${arg}.crt -text | grep -E '(Issuer|Subject):'
	echo "==> PFX"
	${TEST} openssl pkcs12 -export -password pass: -out ${outdir}/${arg}.pfx -inkey ${outdir}/${arg}.key -in ${outdir}/${arg}.crt
	;;
10|client)
	if [ x"$#" != x"1" ]; then
		echo "$0 step ca_name"
		exit 1
	fi
	ca_name=$1; shift
	arg=client
	username=ansible
	subject="/CN=${username}"

	echo "=> Client"
	echo "==> Private Key"
	${TEST} openssl genrsa -out ${outdir}/${arg}.key ${keysize}
	echo "==> CSR"
	${TEST} openssl req -new -key ${outdir}/${arg}.key -out ${outdir}/${arg}.csr -sha256 -subj ${subject}
	echo "==> Certificate"
	#openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out ${outdir}/client.pem -outform PEM -keyout ${outdir}/client_key.pem -subj "/CN=$username" -extensions v3_client -config openssl.conf
	${TEST} openssl x509 -req -days ${period} -CA ${outdir}/${ca_name}.crt -CAkey ${outdir}/${ca_name}.key -CAcreateserial -in ${outdir}/${arg}.csr -out ${outdir}/${arg}.crt -extensions v3_client -extfile openssl.conf
	echo "=> PEM"
	${TEST} openssl x509 -in ${outdir}/${arg}.crt -out ${outdir}/${arg}.pem -outform PEM
	;;
90)
	${TEST} oc new-app https://github.com/orimanabu/openshift-sample-go --name hello
	${TEST} oc expose deploy/hello --port 80 --target-port 8080
	${TEST} oc expose svc/hello
	;;
91)
	${TEST} oc -n openshift-config create configmap custom-ca --from-file=ca-bundle.crt=${outdir}/myca.crt
	${TEST} oc get proxy/cluster -o yaml
	${TEST} oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"custom-ca"}}}'
	;;
92)
	${TEST} oc -n openshift-ingress create secret tls myingress --cert=${outdir}/myingress.crt --key=${outdir}/myingress.key
	${TEST} oc -n openshift-ingress-operator patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "myingress"}}}'     
	;;
93)
	${TEST} oc create route edge hello3 --service=hello --cert=${outdir}/myingress.crt --key=${outdir}/myingress.key --ca-cert=${outdir}/myca.crt --hostname=shello.apps.ocp-odf.lab.local
	;;
94)
	${TEST} sudo cp ${outdir}/myca.crt /etc/pki/ca-trust/source/anchors/
	${TEST} sudo update-ca-trust
	;;
*)
	echo "unknown step: ${step}"
	exit 1
	;;
esac
