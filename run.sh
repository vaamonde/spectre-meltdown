#! /bin/sh
# Script de verificação da vulnerabilidade Spectre & Meltdown nos processadores Intel
# Script compilado em C utilizado o shc: https://github.com/neurobin/shc
# Criado por: Pavel Boldin
# Modificado por: Robson Vaamonde
# Traduzido por: Robson Vaamonde
# Site: www.procedimentosemti.com.br
# Facebook: facebook.com/ProcedimentosEmTI
# Facebook: facebook.com/BoraParaPratica
# YouTube: youtube.com/BoraParaPratica
# Data de atualização: 07/01/2018

find_linux_proc_banner() {
	$2 sed -n -E 's/^(f[0-9a-f]+) .* linux_proc_banner$/\1/p' $1
}

echo "procurando linux_proc_banner em /proc/kallsyms"
linux_proc_banner=$(find_linux_proc_banner /proc/kallsyms)
if test -z $linux_proc_banner; then
	echo "protegido. requer root"
	set -x
	linux_proc_banner=$(\
		find_linux_proc_banner /proc/kallsyms sudo)

	set +x
fi
if test -z $linux_proc_banner; then
	echo "não encontrado. lendo /boot/System.map-$(uname -r)"
	set -x
	linux_proc_banner=$(\
		find_linux_proc_banner /boot/System.map-$(uname -r) sudo)
	set +x
fi
if test -z $linux_proc_banner; then
	echo "não encontrado. lendo /boot/System.map"
	set -x
	linux_proc_banner=$(\
		find_linux_proc_banner /boot/System.map sudo)
	set +x
fi
if test -z $linux_proc_banner; then
	echo "não pode encontrar linux_proc_banner, incapaz de testar"
	exit 0
fi

./meltdown $linux_proc_banner 10
vuln=$?

if test $vuln -eq 132; then
	echo "INSTRUÇÃO ILEGAL"
	echo "tente recompilar com:"
	echo " make CFLAGS='-DHAVE_RDTSCP=0' clean all"
	echo "executar novamente"
fi
if test $vuln -eq 1; then
	echo "POR FAVOR FAÇA ESTE TESTE: https://github.com/paboldin/meltdown-exploit/issues/19"
	echo "VULNERÁVEL"
	uname -rvi
	head /proc/cpuinfo
	exit 1
fi
if test $vuln -eq 0; then
	echo "POR FAVOR FAÇA ESTE TESTE: https://github.com/paboldin/meltdown-exploit/issues/22"
	echo "NÃO VULNERÁVEL"
	uname -rvi
	head /proc/cpuinfo
	exit 0
fi
